import type { AdminAnnouncement } from '@superhut/api-contract';
import { api, toastRequestError } from '../../../services/api';

const statusLabels: Record<AdminAnnouncement['status'], string> = {
  draft: '草稿',
  scheduled: '待发布',
  published: '已发布',
  withdrawn: '已撤回',
};

interface AdminAnnouncementView extends AdminAnnouncement {
  statusLabel: string;
  timeLabel: string;
}

function view(item: AdminAnnouncement): AdminAnnouncementView {
  return {
    ...item,
    statusLabel: statusLabels[item.status],
    timeLabel: item.publishAt ? new Date(item.publishAt).toLocaleString() : '尚未设置发布时间',
  };
}

Page({
  data: {
    items: [] as AdminAnnouncementView[],
    nextCursor: null as string | null,
    loading: true,
    loadingMore: false,
    error: false,
  },
  async onShow() {
    await this.load(true);
  },
  async onReachBottom() {
    if (this.data.nextCursor && !this.data.loadingMore) await this.load(false);
  },
  create() {
    void wx.navigateTo({ url: '/pages/admin/notification-edit/index' });
  },
  edit(event: WechatMiniprogram.BaseEvent) {
    const id = String(event.currentTarget.dataset.id ?? '');
    if (id) void wx.navigateTo({ url: `/pages/admin/notification-edit/index?id=${id}` });
  },
  retry() {
    void this.load(true);
  },
  async load(reset: boolean) {
    if (reset) this.setData({ loading: true, error: false });
    else this.setData({ loadingMore: true });
    try {
      const page = await api.adminNotifications(reset ? '' : (this.data.nextCursor ?? ''));
      this.setData({
        items: reset ? page.items.map(view) : [...this.data.items, ...page.items.map(view)],
        nextCursor: page.nextCursor,
      });
    } catch (error) {
      this.setData({ error: true });
      toastRequestError(error, '通知管理加载失败');
    } finally {
      this.setData({ loading: false, loadingMore: false });
    }
  },
  async withdraw(event: WechatMiniprogram.BaseEvent) {
    const id = String(event.currentTarget.dataset.id ?? '');
    if (!id) return;
    const confirm = await wx.showModal({
      title: '撤回这条公告？',
      content: '撤回后普通用户将无法继续查看，操作会留下审计记录。',
      confirmText: '确认撤回',
      confirmColor: '#a53b32',
    });
    if (!confirm.confirm) return;
    try {
      await api.withdrawAnnouncement(id);
      wx.showToast({ title: '已撤回', icon: 'success' });
      await this.load(true);
    } catch (error) {
      toastRequestError(error, '撤回失败');
    }
  },
});
