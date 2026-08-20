import { api } from '../../services/api';
import { storage } from '../../services/storage';

Page({
  data: { message: '正在准备你的课表…' },
  async onLoad() {
    if (!storage.privacyAccepted()) {
      await wx.redirectTo({ url: '/pages/privacy/index' });
      return;
    }
    if (!storage.accessToken()) {
      await wx.switchTab({ url: '/pages/timetable/index' });
      return;
    }
    const cache = storage.timetable();
    if (cache) {
      await wx.switchTab({ url: '/pages/timetable/index' });
      return;
    }
    try {
      const status = await api.status();
      if (status.academicBinding.status === 'active')
        await wx.switchTab({ url: '/pages/timetable/index' });
      else await wx.redirectTo({ url: '/pages/login/index' });
    } catch {
      await wx.redirectTo({ url: '/pages/login/index' });
    }
  },
});
