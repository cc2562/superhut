import type { Course, Timetable } from '@superhut/api-contract';
import {
  calculateSchoolWeek,
  findNextCourses,
  parseStrictDate,
  sortCourses,
  toDateKey,
} from '@superhut/domain-rules';
import { api } from '../../services/api';
import { storage } from '../../services/storage';

interface DayView {
  date: string;
  label: string;
  weekday: string;
  today: boolean;
  courses: Course[];
}
const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
const dateLabel = (date: Date) => `${date.getMonth() + 1}月${date.getDate()}日`;

Page({
  data: {
    mode: 'week' as 'week' | 'day',
    loading: false,
    hasData: false,
    title: '课表',
    week: 1,
    selectedDate: '',
    days: [] as DayView[],
    nextCourses: [] as Course[],
    fetchedAt: '',
    stale: false,
  },
  timetable: null as Timetable | null,
  touchX: 0,
  onShow() {
    const cache = storage.timetable();
    if (cache) {
      this.render(cache.value, cache.fetchedAt);
      void this.checkStatus();
    } else void this.load();
  },
  async checkStatus() {
    try {
      await api.status();
    } catch (error) {
      if (error instanceof Error) {
        wx.showToast({ title: `${error.message}，已保留原课表`, icon: 'none' });
      }
    }
  },
  async load() {
    try {
      const response = await api.timetable();
      storage.saveTimetable(response.data, response.meta.fetchedAt ?? new Date().toISOString());
      this.render(response.data, response.meta.fetchedAt ?? new Date().toISOString());
    } catch {
      this.setData({ hasData: false });
    }
  },
  render(value: Timetable, fetchedAt: string, selected?: Date) {
    this.timetable = value;
    const first = parseStrictDate(value.firstDay);
    if (!first) return;
    const today = new Date();
    const currentWeek = calculateSchoolWeek(value.firstDay, today) ?? 1;
    const date = selected ?? (currentWeek >= 1 && currentWeek <= value.maxWeek ? today : first);
    const difference = Math.floor(
      (new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime() - first.getTime()) /
        86_400_000,
    );
    const week = Math.min(value.maxWeek, Math.max(1, Math.floor(difference / 7) + 1));
    const monday = new Date(first);
    monday.setDate(first.getDate() + (week - 1) * 7);
    const mode = storage.mode();
    const dates =
      mode === 'day'
        ? [date]
        : Array.from({ length: 7 }, (_, index) => {
            const item = new Date(monday);
            item.setDate(monday.getDate() + index);
            return item;
          });
    const days = dates.map((item) => {
      const key = toDateKey(item);
      return {
        date: key,
        label: dateLabel(item),
        weekday: `周${weekdays[item.getDay()]}`,
        today: key === toDateKey(today),
        courses: sortCourses(value.coursesByDate[key] ?? []),
      };
    });
    const nextCourses = findNextCourses(today, today, value.coursesByDate[toDateKey(today)] ?? []);
    this.setData({
      mode,
      hasData: true,
      title: mode === 'week' ? `第 ${week} 周` : dateLabel(date),
      week,
      selectedDate: toDateKey(date),
      days,
      nextCourses,
      fetchedAt: this.formatFetchedAt(fetchedAt),
      stale: Date.now() - Date.parse(fetchedAt) > 24 * 60 * 60 * 1000,
    });
  },
  formatFetchedAt(value: string) {
    const date = new Date(value);
    return `${date.getMonth() + 1}月${date.getDate()}日 ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
  },
  setMode(event: WechatMiniprogram.BaseEvent) {
    const mode = event.currentTarget.dataset.mode as 'week' | 'day';
    storage.saveMode(mode);
    if (this.timetable)
      this.render(
        this.timetable,
        storage.timetable()?.fetchedAt ?? new Date().toISOString(),
        parseStrictDate(this.data.selectedDate) ?? undefined,
      );
  },
  goToday() {
    if (this.timetable)
      this.render(
        this.timetable,
        storage.timetable()?.fetchedAt ?? new Date().toISOString(),
        new Date(),
      );
  },
  onTouchStart(event: WechatMiniprogram.TouchEvent) {
    this.touchX = event.touches[0]?.clientX ?? 0;
  },
  onTouchEnd(event: WechatMiniprogram.TouchEvent) {
    const end = event.changedTouches[0]?.clientX ?? this.touchX;
    if (Math.abs(end - this.touchX) < 60) return;
    this.move(end < this.touchX ? 1 : -1);
  },
  move(delta: -1 | 1) {
    if (!this.timetable) return;
    const selected = parseStrictDate(this.data.selectedDate);
    const first = parseStrictDate(this.timetable.firstDay);
    if (!selected || !first) return;
    const days = this.data.mode === 'week' ? 7 : 1;
    const next = new Date(selected);
    next.setDate(selected.getDate() + delta * days);
    const last = new Date(first);
    last.setDate(first.getDate() + this.timetable.maxWeek * 7 - 1);
    if (next < first || next > last) return;
    this.render(this.timetable, storage.timetable()?.fetchedAt ?? new Date().toISOString(), next);
  },
  async refresh() {
    if (this.data.loading) return;
    this.setData({ loading: true });
    try {
      const response = await api.refreshTimetable();
      const fetchedAt = response.meta.fetchedAt ?? new Date().toISOString();
      storage.saveTimetable(response.data, fetchedAt);
      this.render(response.data, fetchedAt);
    } catch (error) {
      wx.showToast({
        title: error instanceof Error ? error.message : '刷新失败，已保留原课表',
        icon: 'none',
        duration: 3000,
      });
    } finally {
      this.setData({ loading: false });
    }
  },
  goLogin() {
    void wx.navigateTo({ url: '/pages/login/index' });
  },
});
