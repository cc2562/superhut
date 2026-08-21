import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';
import { bootstrap } from '../src/main.js';
import { FixtureAcademicProvider } from '../src/academic/fixture-academic.provider.js';
import { ApiError } from '../src/common/api-error.js';

describe('fixture API flow', () => {
  let app: NestFastifyApplication;
  let http: FastifyInstance;
  let accessToken = '';
  let refreshToken = '';
  const wechatHeaders = (openid: string) => ({
    'x-wx-source': 'wx-cloud-call-container',
    'x-wx-appid': 'fixture-app-id',
    'x-wx-env': 'fixture-env-id',
    'x-wx-openid': openid,
  });

  beforeAll(async () => {
    process.env.APP_MODE = 'fixture';
    process.env.NODE_ENV = 'test';
    app = await bootstrap();
    await app.init();
    http = app.getHttpAdapter().getInstance() as FastifyInstance;
  });
  afterAll(async () => app.close());

  it('reports liveness without leaking configuration', async () => {
    const response = await http.inject({ method: 'GET', url: '/health/live' });
    expect(response.statusCode).toBe(200);
    expect(response.body).not.toContain('MYSQL_PASSWORD');
  });

  it('requires trusted cloud headers and rejects legacy login codes', async () => {
    const missingHeaders = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    expect(missingHeaders.statusCode).toBe(401);
    const forgedApp = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: { ...wechatHeaders('forged-user'), 'x-wx-appid': 'forged-app-id' },
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    expect(forgedApp.statusCode).toBe(401);
    const legacyCode = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('legacy-user'),
      payload: { code: 'must-not-be-accepted', privacyConsentVersion: '2026-08-18' },
    });
    expect(legacyCode.statusCode).toBe(400);
    expect(legacyCode.json().error.code).toBe('VALIDATION_ERROR');
  });

  it('creates a WeChat session and binds an academic account', async () => {
    const session = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('fixture-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    expect(session.statusCode).toBe(201);
    const sessionBody = session.json();
    accessToken = sessionBody.data.accessToken;
    refreshToken = sessionBody.data.refreshToken;
    const binding = await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: { authorization: `Bearer ${accessToken}` },
      payload: { studentId: '2300000001', password: 'fixture-only' },
    });
    expect(binding.statusCode).toBe(201);
    expect(binding.body).not.toContain('fixture-only');
    expect(binding.body).not.toContain('fixture-academic-token');
  });

  it('atomically refreshes and serves a timetable snapshot', async () => {
    const refreshed = await http.inject({
      method: 'POST',
      url: '/v1/academic/timetable/refresh',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(refreshed.statusCode).toBe(201);
    expect(refreshed.json().data.coursesByDate['2026-08-18']).toHaveLength(2);
    const cached = await http.inject({
      method: 'GET',
      url: '/v1/academic/timetable',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(cached.statusCode).toBe(200);
    expect(cached.json().meta.fetchedAt).toBeTruthy();
  });

  it('keeps the last timetable snapshot when a refresh fails', async () => {
    const before = await http.inject({
      method: 'GET',
      url: '/v1/academic/timetable',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    const provider = app.get(FixtureAcademicProvider);
    const failure = vi
      .spyOn(provider, 'refreshTimetable')
      .mockRejectedValueOnce(
        new ApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', 503, '学校服务器不可用'),
      );
    const refreshed = await http.inject({
      method: 'POST',
      url: '/v1/academic/timetable/refresh',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(refreshed.statusCode).toBe(503);
    expect(refreshed.json().error.code).toBe('ACADEMIC_UPSTREAM_UNAVAILABLE');
    const after = await http.inject({
      method: 'GET',
      url: '/v1/academic/timetable',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(after.json().data).toEqual(before.json().data);
    expect(after.json().meta.fetchedAt).toBe(before.json().meta.fetchedAt);
    failure.mockRestore();
  });

  it('rotates refresh tokens and rejects reuse', async () => {
    const rotated = await http.inject({
      method: 'POST',
      url: '/v1/auth/refresh',
      payload: { refreshToken },
    });
    expect(rotated.statusCode).toBe(201);
    accessToken = rotated.json().data.accessToken;
    const reused = await http.inject({
      method: 'POST',
      url: '/v1/auth/refresh',
      payload: { refreshToken },
    });
    expect(reused.statusCode).toBe(401);
    expect(reused.json().error.code).toBe('AUTH_REQUIRED');
  });

  it('validates room dates and building allowlists', async () => {
    const buildings = await http.inject({
      method: 'GET',
      url: '/v1/academic/rooms/buildings',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(buildings.statusCode).toBe(200);
    const invalid = await http.inject({
      method: 'GET',
      url: '/v1/academic/rooms/free?date=2026-99-99&nodeId=0102&buildingId=public',
      headers: { authorization: `Bearer ${accessToken}` },
    });
    expect(invalid.statusCode).toBe(400);
    expect(invalid.json().error.code).toBe('VALIDATION_ERROR');
  });

  it('removes the academic binding and timetable snapshot together', async () => {
    const session = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('unbind-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    const token = session.json().data.accessToken as string;
    const authorization = { authorization: `Bearer ${token}` };
    await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: authorization,
      payload: { studentId: '2300000003', password: 'fixture-only' },
    });
    await http.inject({
      method: 'POST',
      url: '/v1/academic/timetable/refresh',
      headers: authorization,
    });

    const unbound = await http.inject({
      method: 'DELETE',
      url: '/v1/auth/academic/binding',
      headers: authorization,
    });
    expect(unbound.statusCode).toBe(200);
    const status = await http.inject({
      method: 'GET',
      url: '/v1/auth/academic/status',
      headers: authorization,
    });
    expect(status.json().data.academicBinding.status).toBe('unbound');
    const timetable = await http.inject({
      method: 'GET',
      url: '/v1/academic/timetable',
      headers: authorization,
    });
    expect(timetable.statusCode).toBe(403);
    expect(timetable.json().error.code).toBe('AUTH_ACADEMIC_NOT_BOUND');
  });

  it('revokes one session on logout and every session on account deletion', async () => {
    const logoutSession = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('logout-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    const logoutToken = logoutSession.json().data.accessToken as string;
    const loggedOut = await http.inject({
      method: 'POST',
      url: '/v1/auth/logout',
      headers: { authorization: `Bearer ${logoutToken}` },
    });
    expect(loggedOut.statusCode).toBe(201);
    const revoked = await http.inject({
      method: 'GET',
      url: '/v1/me',
      headers: { authorization: `Bearer ${logoutToken}` },
    });
    expect(revoked.statusCode).toBe(401);

    const first = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('delete-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    const second = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('delete-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    const firstToken = first.json().data.accessToken as string;
    const secondToken = second.json().data.accessToken as string;
    const deleted = await http.inject({
      method: 'DELETE',
      url: '/v1/me',
      headers: { authorization: `Bearer ${firstToken}` },
    });
    expect(deleted.statusCode).toBe(200);
    const allRevoked = await http.inject({
      method: 'GET',
      url: '/v1/me',
      headers: { authorization: `Bearer ${secondToken}` },
    });
    expect(allRevoked.statusCode).toBe(401);
  });

  it('rate limits repeated academic login attempts without exposing account existence', async () => {
    const session = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('rate-limit-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    const token = session.json().data.accessToken as string;
    let response;
    for (let attempt = 0; attempt < 6; attempt += 1) {
      response = await http.inject({
        method: 'POST',
        url: '/v1/auth/academic/login',
        headers: { authorization: `Bearer ${token}` },
        payload: { studentId: '2300000002', password: 'fixture-only' },
      });
    }
    expect(response?.statusCode).toBe(429);
    expect(response?.json().error.code).toBe('ACADEMIC_RATE_LIMITED');
  });
});
