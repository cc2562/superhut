import type { Course, Timetable } from '@superhut/api-contract';
import {
  buildWeekSlots,
  calculateSchoolWeek,
  findNextCourses,
  parseStrictDate,
  sortCourses,
  toDateKey,
} from '@superhut/domain-rules';
import type { WeekSlot } from '@superhut/domain-rules';
import { api, ensureWechatSession, toastRequestError } from '../../services/api';
import { CaptchaCancelledError, mountCaptcha, verifyCaptcha } from '../../services/captcha';
import { storage } from '../../services/storage';

interface DayView {
  date: string;
  label: string;
  weekday: string;
  today: boolean;
  courses: Course[];
  slots: WeekSlot[];
}
type MainTab = 'timetable' | 'services' | 'profile';
interface ActivatablePanel {
  activate(force?: boolean): void | Promise<void>;
}
const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
const dateLabel = (date: Date) => `${date.getMonth() + 1}月${date.getDate()}日`;
const sectionNumbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

Page({
  data: {
    activeTab: 'timetable' as MainTab,
    serviceBadgeProps: { dot: false },
    mode: 'week' as 'week' | 'day',
    loading: false,
    refreshing: false,
    hasData: false,
    title: '课表',
    week: 1,
    selectedDate: '',
    days: [] as DayView[],
    nextCourses: [] as Course[],
    fetchedAt: '',
    semesters: [] as Array<{ id: string; name: string; current: boolean }>,
    semesterNames: [] as string[],
    semesterIndex: 0,
    semesterId: '',
    currentSemesterId: '',
    sectionNumbers,
    loadCaptcha: false,
    pluginProps: null as WechatMiniprogram.IAnyObject | null,
  },
  timetable: null as Timetable | null,
  touchX: 0,
  refreshResult: null as { error?: unknown } | null,
  onLoad() {
    mountCaptcha(this, 'refresh');
  },
  async onShow() {
    await this.activateTab(this.data.activeTab, true);
    if (this.data.activeTab !== 'services') {
      const services = this.selectComponent(
        '#services-panel',
      ) as unknown as ActivatablePanel | null;
      await services?.activate();
    }
  },
  onMainTabChange(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    if (this.data.refreshing) return;
    const value = event.detail.value;
    if (!['timetable', 'services', 'profile'].includes(value)) return;
    const activeTab = value as MainTab;
    if (activeTab === this.data.activeTab) return;
    this.setData({ activeTab }, () => void this.activateTab(activeTab));
  },
  onRefreshStateChange(
    event: WechatMiniprogram.CustomEvent<{ refreshing: boolean; error?: unknown }>,
  ) {
    const refreshing = Boolean(event.detail.refreshing);
    this.refreshResult = refreshing ? null : { error: event.detail.error };
    this.setData({ refreshing });
  },
  onNotificationChange(event: WechatMiniprogram.CustomEvent<{ unreadCount: number }>) {
    this.setData({ serviceBadgeProps: { dot: event.detail.unreadCount > 0 } });
  },
  onRefreshPopupLeaved() {
    const result = this.refreshResult;
    if (!result) return;
    this.refreshResult = null;
    if (result.error) {
      toastRequestError(result.error, '刷新失败，已保留原课表');
      return;
    }
    wx.showToast({ title: '课表已刷新', icon: 'success' });
  },
  async activateTab(tab: MainTab, force = false) {
    if (tab === 'profile') {
      const panel = this.selectComponent('#profile-panel') as unknown as ActivatablePanel | null;
      await panel?.activate(force);
      return;
    }
    if (tab === 'services') {
      const panel = this.selectComponent('#services-panel') as unknown as ActivatablePanel | null;
      await panel?.activate();
      return;
    }
    await this.activateTimetable();
  },
  async activateTimetable() {
    if (!storage.accessToken()) {
      this.timetable = null;
      this.setData({ hasData: false, days: [], nextCourses: [], fetchedAt: '' });
      return;
    }
    await this.ensureSemesters();
    const cache = this.data.semesterId ? storage.timetable(this.data.semesterId) : null;
    if (cache) {
      this.render(cache.value, cache.fetchedAt);
      void this.checkStatus();
    } else if (this.data.semesterId) {
      void this.refresh();
    }
  },
  async ensureSemesters() {
    if (this.data.semesters.length) return;
    try {
      const semesters = await api.semesters();
      const current = semesters.find(({ current }) => current) ?? semesters[0];
      const saved = storage.timetableSemester();
      const semesterId =
        this.data.semesterId ||
        (saved && semesters.some(({ id }) => id === saved) ? saved : current?.id || '');
      const index = Math.max(
        0,
        semesters.findIndex(({ id }) => id === semesterId),
      );
      this.setData({
        semesters,
        semesterNames: semesters.map(({ name, id }) => name || id),
        semesterId,
        semesterIndex: index,
        currentSemesterId: current?.id ?? '',
      });
    } catch {
      /* 未绑定教务等，semesters 拉不到，保持空态 */
    }
  },
  onSemesterChange(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    const index = Number(event.detail.value);
    const semester = this.data.semesters[index];
    if (!semester || semester.id === this.data.semesterId) return;
    this.setData({ semesterId: semester.id, semesterIndex: index });
    storage.saveTimetableSemester(semester.id);
    const cache = storage.timetable(semester.id);
    if (cache) this.render(cache.value, cache.fetchedAt);
    else void this.refresh();
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
  render(value: Timetable, fetchedAt: string, selected?: Date) {
    this.timetable = value;
    const first = parseStrictDate(value.firstDay);
    if (!first) return;
    const today = new Date();
    const isHistorical =
      this.data.currentSemesterId !== '' && this.data.semesterId !== this.data.currentSemesterId;
    let date: Date;
    if (selected) {
      date = selected;
    } else if (isHistorical) {
      // 历史学期（测试用）：直接锚定第一周，不参与「今天是第几周」的计算
      date = first;
    } else {
      const currentWeek = calculateSchoolWeek(value.firstDay, today) ?? 1;
      date = currentWeek >= 1 && currentWeek <= value.maxWeek ? today : first;
    }
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
      const courses = sortCourses(value.coursesByDate[key] ?? []);
      return {
        date: key,
        label: dateLabel(item),
        weekday: `周${weekdays[item.getDay()]}`,
        today: key === toDateKey(today),
        courses,
        slots: buildWeekSlots(courses),
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
        storage.timetable(this.data.semesterId)?.fetchedAt ?? new Date().toISOString(),
        parseStrictDate(this.data.selectedDate) ?? undefined,
      );
  },
  goToday() {
    if (this.timetable)
      this.render(
        this.timetable,
        storage.timetable(this.data.semesterId)?.fetchedAt ?? new Date().toISOString(),
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
    this.render(
      this.timetable,
      storage.timetable(this.data.semesterId)?.fetchedAt ?? new Date().toISOString(),
      next,
    );
  },
  async refresh() {
    if (this.data.loading || this.data.refreshing) return;
    this.setData({ loading: true });
    let captchaVerifyParam: string;
    try {
      // 验证通过前阻断刷新：先完成阿里云刷新场景验证码。
      captchaVerifyParam = await verifyCaptcha();
    } catch (error) {
      this.setData({ loading: false });
      if (error instanceof CaptchaCancelledError) {
        wx.showToast({ title: '已取消验证', icon: 'none' });
      } else {
        toastRequestError(error, '刷新失败，已保留原课表');
      }
      return;
    }

    this.setData({ refreshing: true });
    let requestError: unknown;
    try {
      const response = await api.refreshTimetable(this.data.semesterId, captchaVerifyParam);
      const fetchedAt = response.meta.fetchedAt ?? new Date().toISOString();
      storage.saveTimetable(response.data, fetchedAt);
      this.render(response.data, fetchedAt);
    } catch (error) {
      requestError = error;
    } finally {
      this.refreshResult = { error: requestError };
      this.setData({ loading: false, refreshing: false });
    }
  },
  async goLogin() {
    try {
      await ensureWechatSession();
      const status = await api.status();
      if (status.academicBinding.status === 'active') {
        wx.showToast({ title: '登录成功', icon: 'success' });
        await this.ensureSemesters();
        void this.refresh();
        return;
      }
    } catch {
      /* 恢复失败或未绑定，走登录页 */
    }
    void wx.navigateTo({ url: '/pages/login/index' });
  },
});
