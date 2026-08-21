import { api } from '../../services/api';
import { storage } from '../../services/storage';

const PRIVACY_VERSION = '2026-08-18';
Page({
  data: { agreed: false, loading: false },
  onAgreementChange(event: WechatMiniprogram.CustomEvent<{ value: boolean }>) {
    this.setData({ agreed: event.detail.value });
  },
  async continue() {
    if (!this.data.agreed || this.data.loading) return;
    this.setData({ loading: true });
    try {
      storage.acceptPrivacy(PRIVACY_VERSION);
      const session = await api.wechatLogin(PRIVACY_VERSION);
      storage.saveSession(session.accessToken, session.refreshToken);
      await wx.switchTab({ url: '/pages/timetable/index' });
    } catch {
      wx.showToast({ title: '暂时无法登录，请稍后重试', icon: 'none' });
    } finally {
      this.setData({ loading: false });
    }
  },
});
