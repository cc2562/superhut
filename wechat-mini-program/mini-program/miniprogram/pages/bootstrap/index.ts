import { hasAcceptedCurrentPrivacy, PRIVACY_CONSENT_VERSION } from '../../constants/privacy';
import { api } from '../../services/api';
import { openWechatPrivacyContract } from '../../services/privacy';
import { storage } from '../../services/storage';

interface PrivacySettingApi {
  getPrivacySetting?: (options: {
    success: (result: { needAuthorization: boolean }) => void;
    fail: () => void;
  }) => void;
}

function needsPlatformPrivacyAuthorization(): Promise<boolean> {
  const getPrivacySetting = (wx as unknown as PrivacySettingApi).getPrivacySetting;
  if (!getPrivacySetting) return Promise.resolve(false);
  return new Promise((resolve) => {
    try {
      getPrivacySetting({
        success: ({ needAuthorization }) => resolve(needAuthorization),
        fail: () => resolve(false),
      });
    } catch {
      resolve(false);
    }
  });
}

Page({
  data: {
    message: '正在准备你的课表…',
    preparing: true,
    consentVisible: false,
    privacyAuthorizationRequired: false,
    loading: false,
  },
  async onLoad() {
    if (hasAcceptedCurrentPrivacy(storage.privacyAccepted())) {
      await wx.reLaunch({ url: '/pages/timetable/index' });
      return;
    }
    const privacyAuthorizationRequired = await needsPlatformPrivacyAuthorization();
    this.setData({
      preparing: false,
      consentVisible: true,
      privacyAuthorizationRequired,
      message: '继续使用前，请先了解我们如何提供服务与保护你的信息',
    });
  },
  showConsent() {
    this.setData({ consentVisible: true });
  },
  declineConsent() {
    if (this.data.loading) return;
    this.setData({
      consentVisible: false,
      message: '你尚未同意相关协议，暂时无法使用教务服务',
    });
  },
  openServiceAgreement() {
    void wx.navigateTo({ url: '/pages/agreement/index' });
  },
  openPrivacyContract() {
    openWechatPrivacyContract();
  },
  async agreePrivacyAuthorization() {
    await this.acceptConsent();
  },
  async acceptConsent() {
    if (this.data.loading) return;
    this.setData({ loading: true });
    try {
      const session = await api.wechatLogin(PRIVACY_CONSENT_VERSION);
      storage.saveConsentedSession(
        PRIVACY_CONSENT_VERSION,
        session.accessToken,
        session.refreshToken,
      );
      await wx.reLaunch({ url: '/pages/timetable/index' });
    } catch {
      wx.showToast({ title: '暂时无法登录，请稍后重试', icon: 'none' });
    } finally {
      this.setData({ loading: false });
    }
  },
});
