// 阿里云验证码 2.0（V3 架构）小程序插件封装。
//
// 两个独立验证场景分别对应阿里云验证码控制台「场景管理」中创建的场景 ID：
//  - login   ：登录教务系统
//  - refresh ：刷新课表
const LOGIN_SCENE_ID = '1nvm64gz';
const REFRESH_SCENE_ID = '10qcl9vi';

interface AliyunCaptchaPlugin {
  show(): void;
}

// requirePlugin 返回插件通过 main 暴露的接口；官方插件的实例方法为 show()。
const plugin = requirePlugin('AliyunCaptcha') as AliyunCaptchaPlugin;

export type CaptchaScene = 'login' | 'refresh';

interface CaptchaHost {
  setData(data: WechatMiniprogram.IAnyObject, callback?: () => void): void;
}

/** 用户主动关闭验证码弹窗（取消验证）。 */
export class CaptchaCancelledError extends Error {
  constructor() {
    super('已取消验证');
    this.name = 'CaptchaCancelledError';
  }
}

// 当前进行中的验证 Promise 桥接。验证码弹窗是全局单例，同一时刻只有一次验证流程。
let pendingResolve: ((value: string) => void) | null = null;
let pendingReject: ((error: Error) => void) | null = null;

function settleResolve(value: string): void {
  const resolve = pendingResolve;
  pendingResolve = null;
  pendingReject = null;
  resolve?.(value);
}
function settleReject(error: Error): void {
  const reject = pendingReject;
  pendingResolve = null;
  pendingReject = null;
  reject?.(error);
}

function buildProps(host: CaptchaHost, scene: CaptchaScene): WechatMiniprogram.IAnyObject {
  const sceneId = scene === 'login' ? LOGIN_SCENE_ID : REFRESH_SCENE_ID;
  return {
    SceneId: sceneId,
    mode: 'popup',
    language: 'cn',
    region: 'cn',
    success: (captchaVerifyParam: string) => {
      settleResolve(captchaVerifyParam);
      // 一次验证生命周期结束，立即重新挂载，为下一次验证做准备（避免下次 show 黑屏）。
      reloadCaptcha(host, scene);
    },
    fail: () => {
      settleReject(new Error('验证未通过，请重试'));
      reloadCaptcha(host, scene);
    },
    // 验证成功触发的关闭由 success 处理；这里只处理用户主动关闭（取消验证）。
    onClose: (isVerify: boolean) => {
      if (isVerify) return;
      settleReject(new CaptchaCancelledError());
      reloadCaptcha(host, scene);
    },
  };
}

function reloadCaptcha(host: CaptchaHost, scene: CaptchaScene): void {
  host.setData({ loadCaptcha: false }, () => {
    host.setData({ loadCaptcha: true, pluginProps: buildProps(host, scene) });
  });
}

/**
 * 页面 onLoad 时调用：预挂载验证码组件并完成插件初始化。
 * 提前挂载（而非点击时才挂载）是为了避免「首次点击只出现黑色遮罩、验证码不弹出」：
 * 组件挂载与 show() 之间需要时间差让插件完成初始化。
 *
 * 页面需在 wxml 挂载：
 *   <aliyun-captcha id="captcha" wx:if="{{loadCaptcha}}" props="{{pluginProps}}" />
 */
export function mountCaptcha(host: CaptchaHost, scene: CaptchaScene): void {
  host.setData({ loadCaptcha: true, pluginProps: buildProps(host, scene) });
}

/**
 * 触发验证码弹窗。验证通过后 resolve 为 captchaVerifyParam（原样透传给服务端二次校验）；
 * 用户取消验证 reject CaptchaCancelledError；验证未通过 reject Error('验证未通过，请重试')。
 */
export function verifyCaptcha(): Promise<string> {
  return new Promise((resolve, reject) => {
    pendingResolve = resolve;
    pendingReject = reject;
    plugin.show();
  });
}
