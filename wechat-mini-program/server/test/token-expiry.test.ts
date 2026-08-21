import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';
import { bootstrap } from '../src/main.js';
import { ApiError } from '../src/common/api-error.js';
import { FixtureAcademicProvider } from '../src/academic/fixture-academic.provider.js';

const wechatHeaders = (openid: string) => ({
  'x-wx-source': 'wx-cloud-call-container',
  'x-wx-appid': 'fixture-app-id',
  'x-wx-env': 'fixture-env-id',
  'x-wx-openid': openid,
});

async function bindAccount(
  http: FastifyInstance,
  openid: string,
  studentId: string,
): Promise<string> {
  const session = await http.inject({
    method: 'POST',
    url: '/v1/auth/wechat/login',
    headers: wechatHeaders(openid),
    payload: { privacyConsentVersion: '2026-08-18' },
  });
  const token = session.json().data.accessToken as string;
  await http.inject({
    method: 'POST',
    url: '/v1/auth/academic/login',
    headers: { authorization: `Bearer ${token}` },
    payload: { studentId, password: 'fixture-only' },
  });
  return token;
}

describe('token expiry detection', () => {
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

  it('marks the binding expired and returns AUTH_ACADEMIC_EXPIRED when the token is stale', async () => {
    const token = await bindAccount(http, 'expiry-stale', '2300000020');
    const provider = app.get(FixtureAcademicProvider);
    vi.spyOn(provider, 'exams').mockRejectedValueOnce(
      new ApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', 503, '学校服务器不可用'),
    );
    vi.spyOn(provider, 'validateToken').mockResolvedValueOnce(false);

    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/exams',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(response.statusCode).toBe(401);
    expect(response.json().error.code).toBe('AUTH_ACADEMIC_EXPIRED');
    vi.restoreAllMocks();

    // 标记后，后续查询直接过期，不再调用学校接口
    const examsSpy = vi.spyOn(provider, 'exams');
    const second = await http.inject({
      method: 'GET',
      url: '/v1/academic/exams',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(second.statusCode).toBe(401);
    expect(second.json().error.code).toBe('AUTH_ACADEMIC_EXPIRED');
    expect(examsSpy).not.toHaveBeenCalled();
    vi.restoreAllMocks();
  });

  it('keeps ACADEMIC_UPSTREAM_UNAVAILABLE when the token is still valid', async () => {
    const token = await bindAccount(http, 'expiry-valid', '2300000021');
    const provider = app.get(FixtureAcademicProvider);
    vi.spyOn(provider, 'exams').mockRejectedValueOnce(
      new ApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', 503, '学校服务器不可用'),
    );
    vi.spyOn(provider, 'validateToken').mockResolvedValueOnce(true);

    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/exams',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(response.statusCode).toBe(503);
    expect(response.json().error.code).toBe('ACADEMIC_UPSTREAM_UNAVAILABLE');
    vi.restoreAllMocks();
  });
});
