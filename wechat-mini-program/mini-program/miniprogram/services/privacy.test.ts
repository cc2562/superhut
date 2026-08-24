import { beforeEach, describe, expect, it, vi } from 'vitest';
import { openWechatPrivacyContract } from './privacy';

const showToast = vi.fn();

beforeEach(() => {
  showToast.mockClear();
});

describe('WeChat privacy contract', () => {
  it('explains when the current base library does not support the API', () => {
    vi.stubGlobal('wx', { showToast } as unknown as typeof wx);

    openWechatPrivacyContract();

    expect(showToast).toHaveBeenCalledWith({
      title: '当前微信版本暂不支持查看',
      icon: 'none',
    });
  });

  it('shows a friendly message when the configured contract cannot open', () => {
    vi.stubGlobal('wx', {
      showToast,
      openPrivacyContract: ({ fail }: { fail: () => void }) => fail(),
    } as unknown as typeof wx);

    openWechatPrivacyContract();

    expect(showToast).toHaveBeenCalledWith({
      title: '隐私保护指引暂时无法打开',
      icon: 'none',
    });
  });
});
