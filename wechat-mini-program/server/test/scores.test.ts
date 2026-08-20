import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';
import { bootstrap } from '../src/main.js';

describe('scores API flow', () => {
  let app: NestFastifyApplication;
  let http: FastifyInstance;
  let accessToken = '';
  const wechatHeaders = (openid: string) => ({
    'x-wx-source': 'wx-cloud-call-container',
    'x-wx-appid': 'fixture-app-id',
    'x-wx-env': 'fixture-env-id',
    'x-wx-openid': openid,
  });
  const auth = () => ({ authorization: `Bearer ${accessToken}` });

  beforeAll(async () => {
    process.env.APP_MODE = 'fixture';
    process.env.NODE_ENV = 'test';
    app = await bootstrap();
    await app.init();
    http = app.getHttpAdapter().getInstance() as FastifyInstance;
    const session = await http.inject({
      method: 'POST',
      url: '/v1/auth/wechat/login',
      headers: wechatHeaders('scores-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    accessToken = session.json().data.accessToken as string;
    await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: auth(),
      payload: { studentId: '2300000011', password: 'fixture-only' },
    });
  });
  afterAll(async () => app.close());

  it('returns scores with a summary for a specific semester', async () => {
    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/scores?semesterId=2026-2027-1',
      headers: auth(),
    });
    expect(response.statusCode).toBe(200);
    const data = response.json().data;
    expect(Array.isArray(data.scores)).toBe(true);
    expect(data.scores.length).toBeGreaterThan(0);
    expect(data.scores[0].courseName).toBe('高等数学');
    expect(data.summary.earnedCredits).toBe('40');
    expect(data.summary.averageGradePoint).toBe('3.75');
  });

  it('returns all semesters when semesterId is omitted', async () => {
    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/scores',
      headers: auth(),
    });
    expect(response.statusCode).toBe(200);
    const data = response.json().data;
    expect(Array.isArray(data.scores)).toBe(true);
    expect(data.summary.totalGradePoints).toBe('150');
  });

  it('returns an empty scores list with an empty summary for an empty result', async () => {
    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/scores?semesterId=no-such-semester',
      headers: auth(),
    });
    expect(response.statusCode).toBe(200);
    const data = response.json().data;
    expect(Array.isArray(data.scores)).toBe(true);
    expect(data.summary).toBeTruthy();
  });
});
