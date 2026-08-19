import { api, ClientApiError } from '../../services/api';
import { storage } from '../../services/storage';

Page({
  data: {
    studentId: '',
    password: '',
    remember: false,
    loading: false,
  },
  onStudentId(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ studentId: event.detail.value });
  },
  onPassword(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ password: event.detail.value });
  },
  onRemember(event: WechatMiniprogram.CustomEvent<{ value: boolean }>) {
    this.setData({ remember: event.detail.value });
  },
  async submit() {
    if (!/^\d{6,20}$/.test(this.data.studentId) || !this.data.password) {
      wx.showToast({ title: '请输入正确的学号和密码', icon: 'none' });
      return;
    }
    if (this.data.loading) return;
    this.setData({ loading: true });
    try {
      await api.academicLogin(this.data.studentId, this.data.password);
      if (this.data.remember) await storage.saveCredential(this.data.studentId, this.data.password);
      else await storage.deleteCredential();
      const response = await api.refreshTimetable();
      storage.saveTimetable(response.data, response.meta.fetchedAt ?? new Date().toISOString());
      await wx.switchTab({ url: '/pages/timetable/index' });
    } catch (error) {
      if (error instanceof ClientApiError && error.code === 'AUTH_ACADEMIC_INVALID_CREDENTIALS')
        await storage.deleteCredential();
      wx.showToast({
        title: error instanceof Error ? error.message : '登录失败，请重试',
        icon: 'none',
        duration: 3000,
      });
    } finally {
      this.setData({ loading: false, password: '' });
    }
  },
});
