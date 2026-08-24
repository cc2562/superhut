import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';
import { bootstrap } from '../src/main.js';
import { environment } from '../src/config.js';

describe('notification center', () => {
  let app: NestFastifyApplication;
  let http: FastifyInstance;
  let token = '';
  let normalToken = '';
  let announcementId = '';
  const headers = (openid: string) => ({
    'x-wx-source': 'wx-cloud-call-container',
    'x-wx-appid': 'fixture-app-id',
    'x-wx-env': 'fixture-env-id',
    'x-wx-openid': openid,
  });
  const authorization = () => ({ authorization: `Bearer ${token}` });

  beforeAll(async () => {
    process.env.APP_MODE = 'fixture';
    process.env.NODE_ENV = 'test';
    process.env.ADMIN_USER_IDS = '';
    app = await bootstrap();
    await app.init();
    http = app.getHttpAdapter().getInstance() as FastifyInstance;

    const admin = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: headers('notification-admin'),
      payload: { privacyConsentVersion: '2026-08-24.1' },
    });
    token = admin.json().data.accessToken;
    const me = await http.inject({ method: 'GET', url: '/v1/me', headers: authorization() });
    environment().ADMIN_USER_IDS = me.json().data.id;

    const normal = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: headers('notification-reader'),
      payload: { privacyConsentVersion: '2026-08-24.1' },
    });
    normalToken = normal.json().data.accessToken;
  });

  afterAll(async () => app.close());

  it('keeps admin routes server-authorized', async () => {
    const denied = await http.inject({
      method: 'GET',
      url: '/v1/admin/notifications',
      headers: { authorization: `Bearer ${normalToken}` },
    });
    expect(denied.statusCode).toBe(403);
    expect(denied.json().error.code).toBe('AUTH_FORBIDDEN');
    const capability = await http.inject({
      method: 'GET',
      url: '/v1/admin/notifications/capabilities',
      headers: authorization(),
    });
    expect(capability.json().data.canManage).toBe(true);
  });

  it('keeps drafts and future announcements hidden', async () => {
    const created = await http.inject({
      method: 'POST',
      url: '/v1/admin/notifications',
      headers: authorization(),
      payload: {
        title: '系统维护通知',
        summary: '今晚将进行短时维护',
        content: '维护期间部分教务查询可能暂时不可用。',
        actionPath: '/pages/timetable/index',
        expiresAt: null,
      },
    });
    expect(created.statusCode).toBe(201);
    announcementId = created.json().data.id;

    const empty = await http.inject({
      method: 'GET',
      url: '/v1/notifications/summary',
      headers: { authorization: `Bearer ${normalToken}` },
    });
    expect(empty.json().data).toEqual({ latest: null, unreadCount: 0 });

    const scheduled = await http.inject({
      method: 'POST',
      url: `/v1/admin/notifications/${announcementId}/publish`,
      headers: authorization(),
      payload: { publishAt: new Date(Date.now() + 60_000).toISOString(), expiresAt: null },
    });
    expect(scheduled.json().data.status).toBe('scheduled');
    const stillEmpty = await http.inject({
      method: 'GET',
      url: '/v1/notifications',
      headers: { authorization: `Bearer ${normalToken}` },
    });
    expect(stillEmpty.json().data.items).toEqual([]);
  });

  it('publishes, reads and idempotently marks a notification', async () => {
    const published = await http.inject({
      method: 'POST',
      url: `/v1/admin/notifications/${announcementId}/publish`,
      headers: authorization(),
      payload: { publishAt: new Date(Date.now() - 1_000).toISOString(), expiresAt: null },
    });
    expect(published.json().data.status).toBe('published');

    const summary = await http.inject({
      method: 'GET',
      url: '/v1/notifications/summary',
      headers: { authorization: `Bearer ${normalToken}` },
    });
    expect(summary.json().data.unreadCount).toBe(1);
    expect(summary.json().data.latest.read).toBe(false);

    for (let attempt = 0; attempt < 2; attempt += 1) {
      const read = await http.inject({
        method: 'POST',
        url: `/v1/notifications/${announcementId}/read`,
        headers: { authorization: `Bearer ${normalToken}` },
      });
      expect(read.statusCode).toBe(201);
    }
    const after = await http.inject({
      method: 'GET',
      url: '/v1/notifications/summary',
      headers: { authorization: `Bearer ${normalToken}` },
    });
    expect(after.json().data.unreadCount).toBe(0);
    expect(after.json().data.latest.read).toBe(true);
  });

  it('validates action paths and expiration ordering', async () => {
    const invalidPath = await http.inject({
      method: 'PUT',
      url: `/v1/admin/notifications/${announcementId}`,
      headers: authorization(),
      payload: { actionPath: '/pages/admin/secret' },
    });
    expect(invalidPath.statusCode).toBe(400);
    const invalidExpiration = await http.inject({
      method: 'POST',
      url: `/v1/admin/notifications/${announcementId}/publish`,
      headers: authorization(),
      payload: {
        publishAt: new Date(Date.now() + 60_000).toISOString(),
        expiresAt: new Date().toISOString(),
      },
    });
    expect(invalidExpiration.statusCode).toBe(400);
  });

  it('hides withdrawn announcements', async () => {
    const withdrawn = await http.inject({
      method: 'POST',
      url: `/v1/admin/notifications/${announcementId}/withdraw`,
      headers: authorization(),
    });
    expect(withdrawn.json().data.status).toBe('withdrawn');
    const detail = await http.inject({
      method: 'GET',
      url: `/v1/notifications/${announcementId}`,
      headers: { authorization: `Bearer ${normalToken}` },
    });
    expect(detail.statusCode).toBe(404);
    expect(detail.json().error.code).toBe('RESOURCE_NOT_FOUND');
  });
});
