import { api } from '../../services/api';
import { storage } from '../../services/storage';

Page({
  data: {
    studentIdMasked: '未绑定',
    displayName: '',
    credentialSaved: false,
    cacheTime: '暂无缓存',
  },
  async onShow() {
    const cache = storage.timetable();
    const credential = await storage.credential();
    this.setData({
      credentialSaved: Boolean(credential),
      cacheTime: cache ? new Date(cache.fetchedAt).toLocaleString() : '暂无缓存',
    });
    try {
      const status = await api.status();
      this.setData({
        studentIdMasked: status.academicBinding.studentIdMasked ?? '未绑定',
        displayName: status.academicBinding.displayName ?? '',
      });
    } catch {
      /* cached account state remains */
    }
  },
  relogin() {
    void wx.navigateTo({ url: '/pages/login/index' });
  },
  async deleteCredential() {
    await storage.deleteCredential();
    this.setData({ credentialSaved: false });
    wx.showToast({ title: '已删除', icon: 'success' });
  },
  async clearCache() {
    const confirm = await wx.showModal({
      title: '清除本机数据',
      content: '将清除课表缓存和本机加密保存的密码，但不会解绑教务账号。',
    });
    if (!confirm.confirm) return;
    storage.clearTimetable();
    await storage.deleteCredential();
    this.setData({ credentialSaved: false, cacheTime: '暂无缓存' });
  },
  async unbind() {
    const confirm = await wx.showModal({
      title: '解绑教务账号',
      content: '将删除教务登录状态和服务端课表快照，需要重新登录才能恢复。',
    });
    if (!confirm.confirm) return;
    await api.unbind();
    await wx.reLaunch({ url: '/pages/login/index' });
  },
  async logout() {
    await api.logout();
    await wx.reLaunch({ url: '/pages/bootstrap/index' });
  },
  async deleteAccount() {
    const confirm = await wx.showModal({
      title: '注销 SuperHUT 账号',
      content: '将撤销全部会话并删除教务绑定和快照。此操作不可撤销。',
      confirmColor: '#a53b32',
    });
    if (!confirm.confirm) return;
    await api.deleteAccount();
    await wx.reLaunch({ url: '/pages/privacy/index' });
  },
});
