// 阿里云验证码 2.0（V3 架构）小程序插件封装。
//
// 两个独立验证场景分别对应阿里云验证码控制台「场景管理」中创建的场景 ID：
//  - login   ：登录教务系统
//  - refresh ：刷新课表
// 拿到真实 SceneId 后，替换下方两个占位符常量即可（不要散落在多个页面写死）。
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

/**
 * 触发验证码弹窗。验证通过后 resolve 为 captchaVerifyParam（原样透传给服务端二次校验）；
 * 验证未通过或用户关闭弹窗时 reject。
 *
 * 页面需在 wxml 挂载：
 *   <aliyun-captcha id="captcha" wx:if="{{loadCaptcha}}" props="{{pluginProps}}" />
 */
export function verifyCaptcha(host: CaptchaHost, scene: CaptchaScene): Promise<string> {
  return new Promise((resolve, reject) => {
    const sceneId = scene === 'login' ? LOGIN_SCENE_ID : REFRESH_SCENE_ID;
    host.setData(
      {
        loadCaptcha: true,
        pluginProps: {
          SceneId: sceneId,
          mode: 'popup',
          language: 'cn',
          region: 'cn',
          success: (captchaVerifyParam: string) => {
            host.setData({ loadCaptcha: false });
            resolve(captchaVerifyParam);
          },
          fail: () => {
            host.setData({ loadCaptcha: false });
            reject(new Error('验证未通过，请重试'));
          },
        },
      },
      // setData 渲染完成、组件挂载后再触发验证码弹窗。
      () => plugin.show(),
    );
  });
}
