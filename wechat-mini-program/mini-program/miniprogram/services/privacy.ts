interface PrivacyContractApi {
  openPrivacyContract?: (options: { success: () => void; fail: () => void }) => void;
}

export function openWechatPrivacyContract(): void {
  const openPrivacyContract = (wx as unknown as PrivacyContractApi).openPrivacyContract;
  if (!openPrivacyContract) {
    wx.showToast({ title: '当前微信版本暂不支持查看', icon: 'none' });
    return;
  }
  try {
    openPrivacyContract({
      success: () => undefined,
      fail: () => wx.showToast({ title: '隐私保护指引暂时无法打开', icon: 'none' }),
    });
  } catch {
    wx.showToast({ title: '隐私保护指引暂时无法打开', icon: 'none' });
  }
}
