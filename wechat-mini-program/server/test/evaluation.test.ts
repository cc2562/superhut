import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { NestFastifyApplication } from '@nestjs/platform-fastify';
import type { FastifyInstance } from 'fastify';
import { bootstrap } from '../src/main.js';
import { buildAutoEvaluationTargets } from '../src/academic/academic.service.js';
import type { EvaluationQuestionDto } from '../src/academic/academic-provider.js';

describe('buildAutoEvaluationTargets', () => {
  const questions: EvaluationQuestionDto[] = [
    {
      id: 'q1',
      name: '教学态度是否认真',
      options: [
        { id: 'q1-a', name: '非常认真', score: 5 },
        { id: 'q1-b', name: '较认真', score: 4.5 },
        { id: 'q1-c', name: '一般', score: 4 },
      ],
    },
    {
      id: 'q2',
      name: '教学内容是否充实',
      options: [
        { id: 'q2-a', name: '非常充实', score: 5 },
        { id: 'q2-b', name: '较充实', score: 4.5 },
      ],
    },
  ];

  it('picks a sub-4.75 option for the first question and top scores for the rest', () => {
    expect(buildAutoEvaluationTargets(questions)).toEqual([
      { questionId: 'q1', optionId: 'q1-b' },
      { questionId: 'q2', optionId: 'q2-a' },
    ]);
  });

  it('falls back to the lowest score when the first question has no sub-4.75 option', () => {
    const noLow = [
      {
        id: 'q1',
        name: '题',
        options: [
          { id: 'q1-a', name: '很好', score: 5 },
          { id: 'q1-b', name: '较好', score: 4.8 },
        ],
      },
    ];
    expect(buildAutoEvaluationTargets(noLow)).toEqual([{ questionId: 'q1', optionId: 'q1-b' }]);
  });

  it('skips questions without options', () => {
    const withEmpty = [
      { id: 'q1', name: '题1', options: [{ id: 'q1-a', name: '好', score: 5 }] },
      { id: 'q2', name: '题2', options: [] },
    ];
    expect(buildAutoEvaluationTargets(withEmpty)).toEqual([{ questionId: 'q1', optionId: 'q1-a' }]);
  });
});

describe('evaluation API flow', () => {
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
      headers: wechatHeaders('evaluation-user'),
      payload: { privacyConsentVersion: '2026-08-18' },
    });
    accessToken = session.json().data.accessToken as string;
    await http.inject({
      method: 'POST',
      url: '/v1/auth/academic/login',
      headers: auth(),
      payload: { studentId: '2300000010', password: 'fixture-only' },
    });
  });
  afterAll(async () => app.close());

  it('lists evaluation batches', async () => {
    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/evaluation/batches',
      headers: auth(),
    });
    expect(response.statusCode).toBe(200);
    expect(response.json().data).toHaveLength(1);
    expect(response.json().data[0].id).toBe('fixture-batch');
  });

  it('lists evaluation items with submitted flags', async () => {
    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/evaluation/list?batchId=fixture-batch&pj01id=pj01&pj05id=pj05',
      headers: auth(),
    });
    expect(response.statusCode).toBe(200);
    const items = response.json().data;
    expect(items).toHaveLength(4);
    const byId = Object.fromEntries(
      items.map((item: { courseId: string }) => [item.courseId, item]),
    );
    expect(byId['fixture-course-done'].submitted).toBe(true);
    expect(byId['fixture-course-manual'].submitted).toBe(false);
    expect(byId['fixture-course-auto'].submitted).toBe(false);
    expect(byId['fixture-course-batch'].submitted).toBe(false);
  });

  it('fetches evaluation questions for a course', async () => {
    const response = await http.inject({
      method: 'GET',
      url: '/v1/academic/evaluation/questions?batchId=fixture-batch&evaluationCategoriesId=cat2&courseId=fixture-course-manual&teacherId=t2&noticeId=n2',
      headers: auth(),
    });
    expect(response.statusCode).toBe(200);
    const questions = response.json().data;
    expect(questions).toHaveLength(2);
    expect(questions[0].options.length).toBeGreaterThan(0);
  });

  it('submits a manual evaluation', async () => {
    const response = await http.inject({
      method: 'POST',
      url: '/v1/academic/evaluation/submit',
      headers: auth(),
      payload: {
        batchId: 'fixture-batch',
        courseId: 'fixture-course-manual',
        evaluationCategoriesId: 'cat2',
        teacherId: 't2',
        noticeId: 'n2',
        target: [
          { questionId: 'q1', optionId: 'q1-a' },
          { questionId: 'q2', optionId: 'q2-a' },
        ],
      },
    });
    expect(response.statusCode).toBe(201);
    expect(response.json().data.submitted).toBe(true);
    const list = await http.inject({
      method: 'GET',
      url: '/v1/academic/evaluation/list?batchId=fixture-batch&pj01id=pj01&pj05id=pj05',
      headers: auth(),
    });
    const items = list.json().data;
    const manual = items.find(
      (item: { courseId: string }) => item.courseId === 'fixture-course-manual',
    );
    expect(manual.submitted).toBe(true);
  });

  it('auto-submits a single course', async () => {
    const response = await http.inject({
      method: 'POST',
      url: '/v1/academic/evaluation/auto',
      headers: auth(),
      payload: {
        batchId: 'fixture-batch',
        courseId: 'fixture-course-auto',
        evaluationCategoriesId: 'cat3',
        teacherId: 't3',
        noticeId: 'n3',
      },
    });
    expect(response.statusCode).toBe(201);
    expect(response.json().data.submitted).toBe(true);
  });

  it('auto-submits all remaining pending courses', async () => {
    const response = await http.inject({
      method: 'POST',
      url: '/v1/academic/evaluation/auto-all',
      headers: auth(),
      payload: { pj01id: 'pj01', batchId: 'fixture-batch', pj05id: 'pj05' },
    });
    expect(response.statusCode).toBe(201);
    const result = response.json().data;
    expect(result.total).toBe(1);
    expect(result.succeeded).toBe(1);
    expect(result.failed).toBe(0);
    const list = await http.inject({
      method: 'GET',
      url: '/v1/academic/evaluation/list?batchId=fixture-batch&pj01id=pj01&pj05id=pj05',
      headers: auth(),
    });
    const items = list.json().data;
    expect(items.every((item: { submitted: boolean }) => item.submitted)).toBe(true);
  });

  it('rejects a submission with an empty target list', async () => {
    const response = await http.inject({
      method: 'POST',
      url: '/v1/academic/evaluation/submit',
      headers: auth(),
      payload: {
        batchId: 'fixture-batch',
        courseId: 'fixture-course-manual',
        evaluationCategoriesId: 'cat2',
        teacherId: 't2',
        noticeId: 'n2',
        target: [],
      },
    });
    expect(response.statusCode).toBe(400);
    expect(response.json().error.code).toBe('VALIDATION_ERROR');
  });
});
