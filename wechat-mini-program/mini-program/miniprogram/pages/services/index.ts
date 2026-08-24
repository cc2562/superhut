import type { Announcement } from '@superhut/api-contract';
import { api } from '../../services/api';

Component({
  options: {
    styleIsolation: 'apply-shared',
  },
  data: {
    notificationLoading: false,
    notificationError: false,
    latestAnnouncement: null as Announcement | null,
    unreadCount: 0,
    services: [
      {
        title: '成绩',
        initial: '成',
        description: '按学期查看课程成绩、学分与绩点',
        route: '/pages/scores/index',
        tone: 'green',
      },
      {
        title: '考试',
        initial: '考',
        description: '查看考试科目、时间与地点',
        route: '/pages/exams/index',
        tone: 'blue',
      },
      {
        title: '空教室',
        initial: '室',
        description: '按日期、教学楼和节次查询',
        route: '/pages/rooms/index',
        tone: 'purple',
      },
      {
        title: '评教',
        initial: '评',
        description: '查看待评课程，支持手动或一键评教',
        route: '/pages/evaluation/batches/index',
        tone: 'orange',
      },
    ],
  },
  methods: {
    async activate() {
      await this.loadNotificationSummary();
    },
    async loadNotificationSummary() {
      if (this.data.notificationLoading) return;
      this.setData({ notificationLoading: true, notificationError: false });
      try {
        const summary = await api.notificationSummary();
        this.setData({
          latestAnnouncement: summary.latest,
          unreadCount: summary.unreadCount,
        });
        this.triggerEvent('notificationchange', { unreadCount: summary.unreadCount });
      } catch {
        this.setData({ notificationError: true });
      } finally {
        this.setData({ notificationLoading: false });
      }
    },
    retryNotifications() {
      void this.loadNotificationSummary();
    },
    openLatest() {
      const latest = this.data.latestAnnouncement;
      if (!latest) {
        this.openNotifications();
        return;
      }
      void wx.navigateTo({ url: `/pages/notifications/detail/index?id=${latest.id}` });
    },
    openNotifications() {
      void wx.navigateTo({ url: '/pages/notifications/index' });
    },
    open(event: WechatMiniprogram.BaseEvent) {
      void wx.navigateTo({ url: event.currentTarget.dataset.route as string });
    },
  },
});
