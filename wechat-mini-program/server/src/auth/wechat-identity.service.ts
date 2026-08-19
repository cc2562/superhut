import { Injectable } from '@nestjs/common';
import type { IncomingHttpHeaders } from 'node:http';
import { ApiError } from '../common/api-error.js';
import { environment } from '../config.js';

@Injectable()
export class WechatIdentityService {
  fromTrustedHeaders(headers: IncomingHttpHeaders): { openid: string; unionid?: string } {
    const source = this.value(headers['x-wx-source']);
    const appId = this.value(headers['x-wx-appid']);
    const envId = this.value(headers['x-wx-env']);
    const openid = this.value(headers['x-wx-openid']);
    const unionid = this.value(headers['x-wx-unionid']);
    const env = environment();
    if (
      !source ||
      !openid ||
      appId !== env.ALLOWED_MINIPROGRAM_APP_ID ||
      envId !== env.WECHAT_CLOUD_ENV_ID
    ) {
      throw new ApiError('AUTH_REQUIRED', 401, '微信云托管身份验证失败');
    }
    return unionid ? { openid, unionid } : { openid };
  }

  private value(value: string | string[] | undefined): string {
    return typeof value === 'string' ? value.trim() : '';
  }
}
