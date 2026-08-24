import { api, ensureWechatSession, toastRequestError } from '../../services/api';
import { CaptchaCancelledError, verifyCaptcha } from '../../services/captcha';
import { storage } from '../../services/storage';

Component({
  options: {
    styleIsolation: 'apply-shared',
  },
  data: {
    studentIdMasked: '未绑定',
    displayName: '',
    credentialSaved: false,
    cacheTime: '暂无缓存',
    loggedIn: true,
    activated: false,
    refreshBusy: false,
    canManageNotifications: false,
  },
  methods: {
    async activate(force = false) {
      if (this.data.activated && !force) return;
      const cache = storage.latestTimetable();
      const credential = await storage.credential();
      const loggedIn = Boolean(storage.accessToken());
      this.setData({
        activated: true,
        credentialSaved: Boolean(credential),
        cacheTime: cache ? new Date(cache.fetchedAt).toLocaleString() : '暂无缓存',
        loggedIn,
      });
      if (!loggedIn) {
        this.setData({ studentIdMasked: '未登录', displayName: '' });
        return;
      }
      try {
        const [status, capabilities] = await Promise.all([
          api.status(),
          api.notificationAdminCapabilities().catch(() => ({ canManage: false })),
        ]);
        this.setData({
          studentIdMasked: status.academicBinding.studentIdMasked ?? '未绑定',
          displayName: status.academicBinding.displayName ?? '',
          canManageNotifications: capabilities.canManage,
        });
      } catch {
        /* cached account state remains */
      }
    },
    async relogin() {
      if (this.data.loggedIn) {
        void wx.navigateTo({ url: '/pages/login/index' });
        return;
      }
      try {
        await ensureWechatSession();
        const status = await api.status();
        if (status.academicBinding.status === 'active') {
          wx.showToast({ title: '登录成功', icon: 'success' });
          await this.activate();
          return;
        }
      } catch {
        /* 恢复失败或未绑定，走登录页 */
      }
      void wx.navigateTo({ url: '/pages/login/index' });
    },
    async deleteCredential() {
      await storage.deleteCredential();
      this.setData({ credentialSaved: false });
      wx.showToast({ title: '已删除', icon: 'success' });
    },
    async refreshTimetable() {
      if (this.data.refreshBusy) return;
      this.setData({ refreshBusy: true });
      // 验证通过前阻断刷新：先完成阿里云刷新场景验证码。
      let captchaVerifyParam: string;
      try {
        captchaVerifyParam = await verifyCaptcha();
      } catch (error) {
        this.setData({ refreshBusy: false });
        if (error instanceof CaptchaCancelledError) {
          wx.showToast({ title: '已取消验证', icon: 'none' });
          return;
        }
        toastRequestError(error, '刷新失败');
        return;
      }
      this.triggerEvent('refreshstatechange', { refreshing: true });
      let requestError: unknown;
      try {
        const response = await api.refreshTimetable('', captchaVerifyParam);
        const fetchedAt = response.meta.fetchedAt ?? new Date().toISOString();
        storage.saveTimetable(response.data, fetchedAt);
        this.setData({ cacheTime: new Date(fetchedAt).toLocaleString() });
      } catch (error) {
        requestError = error;
      } finally {
        this.setData({ refreshBusy: false });
        this.triggerEvent('refreshstatechange', { refreshing: false, error: requestError });
      }
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
    openAgreement() {
      void wx.navigateTo({ url: '/pages/agreement/index' });
    },
    openNotificationAdmin() {
      void wx.navigateTo({ url: '/pages/admin/notifications/index' });
    },
    async unbind() {
      const confirm = await wx.showModal({
        title: '解绑教务账号',
        content: '将删除教务登录状态和服务端课表快照，需要重新登录才能恢复。',
      });
      if (!confirm.confirm) return;
      try {
        await api.unbind();
        await wx.reLaunch({ url: '/pages/login/index' });
      } catch (error) {
        wx.showToast({
          title: error instanceof Error ? error.message : '解绑失败，请重试',
          icon: 'none',
        });
      }
    },
    async logout() {
      const confirm = await wx.showModal({
        title: '退出登录',
        content: '将退出当前账号并清除课表缓存，教务账号绑定会保留。',
      });
      if (!confirm.confirm) return;
      try {
        await api.logout();
        await wx.reLaunch({ url: '/pages/bootstrap/index' });
      } catch (error) {
        wx.showToast({
          title: error instanceof Error ? error.message : '退出失败，请重试',
          icon: 'none',
        });
      }
    },
    async deleteAccount() {
      const confirm = await wx.showModal({
        title: '注销 SuperHUT 账号',
        content: '将撤销全部会话并删除教务绑定和快照。此操作不可撤销。',
        confirmColor: '#a53b32',
      });
      if (!confirm.confirm) return;
      try {
        await api.deleteAccount();
        await wx.reLaunch({ url: '/pages/bootstrap/index' });
      } catch (error) {
        wx.showToast({
          title: error instanceof Error ? error.message : '注销失败，请重试',
          icon: 'none',
        });
      }
    },
  },
});
