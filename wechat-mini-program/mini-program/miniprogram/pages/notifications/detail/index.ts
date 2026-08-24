import type { Announcement } from '@superhut/api-contract';
import { api, toastRequestError } from '../../../services/api';

Page({
  data: {
    item: null as Announcement | null,
    publishLabel: '',
    loading: true,
    error: false,
  },
  id: '',
  async onLoad(options: Record<string, string | undefined>) {
    this.id = options.id ?? '';
    await this.load();
  },
  retry() {
    void this.load();
  },
  async load() {
    if (!this.id) {
      this.setData({ loading: false, error: true });
      return;
    }
    this.setData({ loading: true, error: false });
    try {
      const item = await api.notification(this.id);
      this.setData({ item, publishLabel: new Date(item.publishAt).toLocaleString() });
      if (!item.read) {
        try {
          await api.markNotificationRead(item.id);
          this.setData({ 'item.read': true });
        } catch {
          // 正文已经成功加载；已读同步失败不应遮住用户正在查看的内容。
        }
      }
    } catch (error) {
      this.setData({ error: true });
      toastRequestError(error, '通知加载失败');
    } finally {
      this.setData({ loading: false });
    }
  },
  openAction() {
    const path = this.data.item?.actionPath;
    if (!path) return;
    if (path === '/pages/timetable/index') {
      void wx.reLaunch({ url: path });
      return;
    }
    void wx.navigateTo({ url: path });
  },
});
