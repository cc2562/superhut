import { createHash, createHmac, randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { AuditService } from '../audit/audit.service.js';
import { ApiError } from '../common/api-error.js';
import { environment } from '../config.js';

export type CaptchaScene = 'login' | 'refresh';

interface VerifyResponse {
  Success?: boolean;
  Code?: string;
  Result?: { VerifyResult?: boolean; VerifyCode?: string };
}

const sha256Hex = (value: string): string => createHash('sha256').update(value).digest('hex');
const hmacSha256Hex = (key: string, value: string): string =>
  createHmac('sha256', key).update(value).digest('hex');

/**
 * 阿里云验证码 2.0（V3 架构）服务端二次校验。
 *
 * 前端插件回调产生的 captchaVerifyParam 由客户端原样透传，服务端调用
 * VerifyIntelligentCaptcha 完成真正的人机校验（安全边界在服务端，前端弹码只是交互入口）。
 *
 * 调用方式采用 HTTPS 原生调用 + ACS3-HMAC-SHA256 签名（阿里云 RPC V3 签名规范），
 * 不引入官方 SDK 依赖，避免云托管 Node 24 下的依赖链与兼容风险。
 */
@Injectable()
export class CaptchaService {
  constructor(@Inject(AuditService) private readonly audit: AuditService) {}

  async verify(captchaVerifyParam: string, scene: CaptchaScene): Promise<void> {
    const env = environment();
    // fixture 模式（本地/CI 测试）跳过真实校验，保证现有测试与开发不受影响。
    if (env.APP_MODE === 'fixture') return;

    const sceneId =
      scene === 'login' ? env.ALIYUN_CAPTCHA_LOGIN_SCENE_ID : env.ALIYUN_CAPTCHA_REFRESH_SCENE_ID;
    const requestId = randomUUID();

    // 请求体按 RPC form-urlencoded 规范，key 按字典序排列。
    const body = [
      `CaptchaVerifyParam=${encodeURIComponent(captchaVerifyParam)}`,
      `SceneId=${encodeURIComponent(sceneId)}`,
    ].join('&');
    const contentSha256 = sha256Hex(body);
    // 阿里云要求 UTC ISO 8601 精确到秒（不含毫秒）。
    const acsDate = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
    const nonce = randomUUID();

    const action = 'VerifyIntelligentCaptcha';
    const version = '2023-03-05';
    const signed: Record<string, string> = {
      host: env.ALIYUN_CAPTCHA_ENDPOINT,
      'x-acs-action': action,
      'x-acs-content-sha256': contentSha256,
      'x-acs-date': acsDate,
      'x-acs-signature-nonce': nonce,
      'x-acs-version': version,
    };
    const signedKeys = Object.keys(signed).sort();
    const signedHeaders = signedKeys.join(';');
    const canonicalHeaders = `${signedKeys.map((key) => `${key}:${signed[key]}`).join('\n')}\n`;
    const canonicalRequest = ['POST', '/', '', canonicalHeaders, signedHeaders, contentSha256].join(
      '\n',
    );
    const stringToSign = `ACS3-HMAC-SHA256\n${sha256Hex(canonicalRequest)}`;
    const signature = hmacSha256Hex(env.ALIYUN_CAPTCHA_ACCESS_KEY_SECRET, stringToSign);
    const authorization = `ACS3-HMAC-SHA256 Credential=${env.ALIYUN_CAPTCHA_ACCESS_KEY_ID},SignedHeaders=${signedHeaders},Signature=${signature}`;

    try {
      const response = await fetch(`https://${env.ALIYUN_CAPTCHA_ENDPOINT}/`, {
        method: 'POST',
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
          authorization,
          'x-acs-action': action,
          'x-acs-content-sha256': contentSha256,
          'x-acs-date': acsDate,
          'x-acs-signature-nonce': nonce,
          'x-acs-version': version,
        },
        body,
        signal: AbortSignal.timeout(5000),
      });
      const json = (await response.json()) as VerifyResponse;
      if (json.Result?.VerifyResult !== true) {
        await this.audit.record({
          eventType: `captcha.${scene}.verify`,
          result: 'failure',
          requestId,
        });
        throw new ApiError('CAPTCHA_VERIFY_FAILED', 401, '验证未通过，请重试');
      }
    } catch (error) {
      if (error instanceof ApiError) throw error;
      // fail-closed：验证码服务故障（网络异常/超时/欠费/配置错误）时拒绝放行。
      await this.audit.record({
        eventType: `captcha.${scene}.unavailable`,
        result: 'failure',
        requestId,
      });
      throw new ApiError('CAPTCHA_SERVICE_UNAVAILABLE', 503, '验证服务暂不可用，请稍后重试');
    }
  }
}
