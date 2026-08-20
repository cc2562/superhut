import { toDateKey } from '@superhut/domain-rules';
import { api, toastRequestError } from '../../services/api';

Page({
  data: {
    date: String(toDateKey(new Date())),
    nodeId: '0102',
    buildings: [] as Array<{ id: string; name: string }>,
    buildingId: '',
    buildingName: '',
    rooms: [] as Array<{ id: string; name: string }>,
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
  async search() {
    if (!this.data.buildingId) return;
    this.setData({ loading: true });
    try {
      this.setData({
        rooms: await api.rooms(this.data.date, this.data.nodeId, this.data.buildingId),
      });
    } catch (error) {
      toastRequestError(error, '查询失败');
    } finally {
      this.setData({ loading: false });
    }
  },
});
