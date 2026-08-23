import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';
import { bootstrap } from '../src/main.js';

const wechatHeaders = (openid: string) => ({
  'x-wx-source': 'wx-cloud-call-container',
  'x-wx-appid': 'fixture-app-id',
  'x-wx-env': 'fixture-env-id',
  'x-wx-openid': openid,
});

async function sessionFor(http: FastifyInstance, openid: string): Promise<string> {
  const session = await http.inject({
    method: 'POST',
    url: '/v1/auth/wechat/login',
    headers: wechatHeaders(openid),
    payload: { privacyConsentVersion: '2026-08-18' },
  });
  return session.json().data.accessToken as string;
}

describe('captcha protection', () => {
  let app: NestFastifyApplication;
  let http: FastifyInstance;

  beforeAll(async () => {
    process.env.APP_MODE = 'fixture';
    process.env.NODE_ENV = 'test';
    app = await bootstrap();
    await app.init();
    http = app.getHttpAdapter().getInstance() as FastifyInstance;
  });
  afterAll(async () => app.close());

  it('rejects academic login without a captcha verify param', async () => {
    const token = await sessionFor(http, 'captcha-login-missing');
    const response = await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: { authorization: `Bearer ${token}` },
      payload: { studentId: '2300000101', password: 'fixture-only' },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('CAPTCHA_REQUIRED');
  });

  it('rejects timetable refresh without a captcha verify param', async () => {
    const token = await sessionFor(http, 'captcha-refresh-missing');
    await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        studentId: '2300000102',
        password: 'fixture-only',
        captchaVerifyParam: 'fixture-captcha',
      },
    });
    const response = await http.inject({
      method: 'POST',
      url: '/v1/academic/timetable/refresh',
      headers: { authorization: `Bearer ${token}` },
      payload: {},
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('CAPTCHA_REQUIRED');
  });

  it('returns the timetable alongside the binding on login success', async () => {
    const token = await sessionFor(http, 'captcha-login-success');
    const response = await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: { authorization: `Bearer ${token}` },
      payload: {
        studentId: '2300000103',
        password: 'fixture-only',
        captchaVerifyParam: 'fixture-captcha',
      },
    });
    expect(response.statusCode).toBe(201);
    const body = response.json().data;
    expect(body.academicBinding.status).toBe('active');
    expect(body.timetable).toBeTruthy();
    expect(body.timetable.semesterId).toBeTruthy();
    expect(body.timetableFetchedAt).toBeTruthy();
  });

  it('relogin succeeds for the already-bound student and fails otherwise', async () => {
    const token = await sessionFor(http, 'captcha-relogin-user');
    const auth = { authorization: `Bearer ${token}` };
    await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: auth,
      payload: {
        studentId: '2300000104',
        password: 'fixture-only',
        captchaVerifyParam: 'fixture-captcha',
      },
    });

    // 同学号重登：豁免验证码，成功。
    const ok = await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/relogin',
      headers: auth,
      payload: { studentId: '2300000104', password: 'fixture-only' },
    });
    expect(ok.statusCode).toBe(201);
    expect(ok.json().data.academicBinding.status).toBe('active');

    // 不同学号：按凭据错误处理，不泄露账号是否存在。
    const mismatch = await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/relogin',
      headers: auth,
      payload: { studentId: '2300000999', password: 'fixture-only' },
    });
    expect(mismatch.statusCode).toBe(401);
    expect(mismatch.json().error.code).toBe('AUTH_ACADEMIC_INVALID_CREDENTIALS');
  });

  it('relogin rejects when no academic binding exists', async () => {
    const token = await sessionFor(http, 'captcha-relogin-unbound');
    const response = await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/relogin',
      headers: { authorization: `Bearer ${token}` },
      payload: { studentId: '2300000105', password: 'fixture-only' },
    });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe('AUTH_ACADEMIC_INVALID_CREDENTIALS');
  });
});
