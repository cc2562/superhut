import type { Announcement } from '@superhut/api-contract';
import { api, toastRequestError } from '../../services/api';

interface AnnouncementView extends Announcement {
  publishLabel: string;
}

function view(item: Announcement): AnnouncementView {
  return { ...item, publishLabel: new Date(item.publishAt).toLocaleString() };
}

Page({
  data: {
    items: [] as AnnouncementView[],
    nextCursor: null as string | null,
    loading: true,
    loadingMore: false,
    error: false,
  },
  async onLoad() {
    await this.load(true);
  },
  async onShow() {
    if (!this.data.loading && this.data.items.length) await this.load(true);
  },
  async onPullDownRefresh() {
    await this.load(true);
    wx.stopPullDownRefresh();
  },
  async onReachBottom() {
    if (this.data.nextCursor && !this.data.loadingMore) await this.load(false);
  },
  retry() {
    void this.load(true);
  },
  async load(reset: boolean) {
    if (reset) this.setData({ loading: true, error: false });
    else this.setData({ loadingMore: true });
    try {
      const page = await api.notifications(reset ? '' : (this.data.nextCursor ?? ''));
      this.setData({
        items: reset ? page.items.map(view) : [...this.data.items, ...page.items.map(view)],
        nextCursor: page.nextCursor,
      });
    } catch (error) {
      this.setData({ error: true });
      if (!reset) toastRequestError(error, '加载更多通知失败');
    } finally {
      this.setData({ loading: false, loadingMore: false });
    }
  },
  open(event: WechatMiniprogram.BaseEvent) {
    const id = String(event.currentTarget.dataset.id ?? '');
    if (id) void wx.navigateTo({ url: `/pages/notifications/detail/index?id=${id}` });
  },
});
