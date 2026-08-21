import type { FreeRoom } from '@superhut/api-contract';
import { toDateKey } from '@superhut/domain-rules';
import { api, toastRequestError } from '../../services/api';

interface SlotView {
  label: string;
  booked: boolean;
}
interface RoomView extends FreeRoom {
  expanded: boolean;
  slots: SlotView[];
}

function buildSlots(occupied: string[]): SlotView[] {
  return Array.from({ length: 12 }, (_, index) => {
    const slot = String(index + 1).padStart(2, '0');
    return { label: String(index + 1), booked: occupied.some((segment) => segment.includes(slot)) };
  });
}

Page({
  data: {
    date: String(toDateKey(new Date())),
    startLesson: 1,
    endLesson: 2,
    lessonRange: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
    buildings: [] as Array<{ id: string; name: string }>,
    buildingId: '',
    buildingName: '',
    rooms: [] as RoomView[],
    loading: false,
  },
  async onLoad() {
    try {
      const buildings = await api.buildings();
      this.setData({
        buildings,
        buildingId: buildings[0]?.id ?? '',
        buildingName: buildings[0]?.name ?? '',
      });
    } catch (error) {
      toastRequestError(error, '加载失败');
    }
  },
  onDate(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ date: event.detail.value });
  },
  onBuilding(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    const building = this.data.buildings[Number(event.detail.value)];
    if (building) this.setData({ buildingId: building.id, buildingName: building.name });
  },
  onStart(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    const start = Number(event.detail.value) + 1;
    this.setData({ startLesson: start, endLesson: Math.max(this.data.endLesson, start) });
  },
  onEnd(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    const end = Number(event.detail.value) + 1;
    this.setData({ endLesson: end, startLesson: Math.min(this.data.startLesson, end) });
  },
  nodeId(): string {
    return `${String(this.data.startLesson).padStart(2, '0')}${String(this.data.endLesson).padStart(2, '0')}`;
  },
  async search() {
    if (!this.data.buildingId) return;
    this.setData({ loading: true });
    try {
      const rooms = await api.rooms(this.data.date, this.nodeId(), this.data.buildingId);
      this.setData({
        rooms: rooms.map((room) => ({
          ...room,
          expanded: false,
          slots: buildSlots(room.occupied),
        })),
      });
    } catch (error) {
      toastRequestError(error, '查询失败');
    } finally {
      this.setData({ loading: false });
    }
  },
  toggle(event: WechatMiniprogram.BaseEvent) {
    const index = Number(event.currentTarget.dataset.index);
    const room = this.data.rooms[index];
    if (!room) return;
    this.setData({ [`rooms[${index}].expanded`]: !room.expanded });
  },
});
