import { storage } from '../../services/storage';

Page({
  data: { message: '正在准备你的课表…' },
  async onLoad() {
    if (!storage.privacyAccepted()) {
      await wx.redirectTo({ url: '/pages/privacy/index' });
      return;
    }
    await wx.switchTab({ url: '/pages/timetable/index' });
  },
});
