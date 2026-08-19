App({
  onLaunch() {
    wx.cloud.init({ env: 'prod-d2gm96mrjfb4565b0' });
  },
  globalData: {
    cloudEnvId: 'prod-d2gm96mrjfb4565b0',
    cloudService: 'superhut-api',
  },
});
