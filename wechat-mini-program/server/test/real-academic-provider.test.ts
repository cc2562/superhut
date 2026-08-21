import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RealAcademicProvider } from '../src/academic/real-academic.provider.js';
import { isValidNodeId } from '../src/academic/academic.service.js';

const fixtureDirectory = resolve(dirname(fileURLToPath(import.meta.url)), 'fixtures/hut-academic');

async function fixture(name: string): Promise<unknown> {
  return JSON.parse(await readFile(resolve(fixtureDirectory, name), 'utf8')) as unknown;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

async function expectApiError(promise: Promise<unknown>, code: string): Promise<void> {
  await expect(promise).rejects.toMatchObject({ code });
}

describe('real academic upstream contract', () => {
  beforeEach(() => {
    process.env.APP_MODE = 'fixture';
    process.env.ACADEMIC_PASSWORD_KEY = 'fictional-key-123';
    vi.restoreAllMocks();
  });

  it('maps a recognized login failure without leaking the transformed password', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue(jsonResponse({ code: '0', data: null }));
    const provider = new RealAcademicProvider();
    await expectApiError(
      provider.login('2300000000', 'fictional-password'),
      'AUTH_ACADEMIC_INVALID_CREDENTIALS',
    );
    const requestedUrl = String(fetchMock.mock.calls[0]?.[0]);
    expect(requestedUrl).not.toContain('fictional-password');
  });

  it('treats a successful-looking login without a token as an upstream change', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      jsonResponse({ code: '1', data: { name: '测试用户' } }),
    );
    await expectApiError(
      new RealAcademicProvider().login('2300000000', 'fictional-password'),
      'ACADEMIC_UPSTREAM_CHANGED',
    );
  });

  it('distinguishes valid, expired and unknown token responses', async () => {
    const fetchMock = vi
      .spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse({ code: 1, data: [] }))
      .mockResolvedValueOnce(jsonResponse({ code: '0', data: null }))
      .mockResolvedValueOnce(jsonResponse({ code: 'new-shape', data: [] }));
    const provider = new RealAcademicProvider();
    await expect(provider.validateToken('fictional-token')).resolves.toBe(true);
    await expect(provider.validateToken('fictional-token')).resolves.toBe(false);
    await expectApiError(provider.validateToken('fictional-token'), 'ACADEMIC_UPSTREAM_CHANGED');
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it('maps authenticated HTTP rejection to token expiry without hiding other failures', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse({ ignored: true }, 401))
      .mockResolvedValueOnce(jsonResponse({ ignored: true }, 403));
    const provider = new RealAcademicProvider();
    await expect(provider.validateToken('fictional-token')).resolves.toBe(false);
    await expectApiError(provider.exams('fictional-token'), 'AUTH_ACADEMIC_EXPIRED');
  });

  it('maps the documented school 500/code=401 token response without hiding other 5xx', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse({ code: 401, Msg: 'fictional', data: null }, 500))
      .mockResolvedValueOnce(jsonResponse({ code: 500, data: null }, 500));
    const provider = new RealAcademicProvider();
    await expect(provider.validateToken('fictional-token')).resolves.toBe(false);
    await expectApiError(provider.exams('fictional-token'), 'ACADEMIC_UPSTREAM_UNAVAILABLE');
  });

  it('maps HTML and malformed JSON to upstream changed', async () => {
    const html = await readFile(resolve(fixtureDirectory, 'non-json.html'), 'utf8');
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(
        new Response(html, { status: 200, headers: { 'content-type': 'text/html' } }),
      )
      .mockResolvedValueOnce(
        new Response('{', {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
      );
    const provider = new RealAcademicProvider();
    await expectApiError(provider.semesters('fictional-token'), 'ACADEMIC_UPSTREAM_CHANGED');
    await expectApiError(provider.semesters('fictional-token'), 'ACADEMIC_UPSTREAM_CHANGED');
  });

  it('maps 429, 5xx and network timeouts without inspecting response bodies', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse({ ignored: true }, 429))
      .mockResolvedValueOnce(jsonResponse({ ignored: true }, 503))
      .mockRejectedValueOnce(new DOMException('timed out', 'TimeoutError'));
    const provider = new RealAcademicProvider();
    await expectApiError(provider.exams('fictional-token'), 'ACADEMIC_RATE_LIMITED');
    await expectApiError(provider.exams('fictional-token'), 'ACADEMIC_UPSTREAM_UNAVAILABLE');
    await expectApiError(provider.exams('fictional-token'), 'ACADEMIC_UPSTREAM_UNAVAILABLE');
  });

  it('accepts empty list responses and rejects an object in place of a list', async () => {
    vi.spyOn(globalThis, 'fetch')
      .mockResolvedValueOnce(jsonResponse(await fixture('empty-list.json')))
      .mockResolvedValueOnce(jsonResponse(await fixture('changed-object.json')));
    const provider = new RealAcademicProvider();
    await expect(provider.exams('fictional-token')).resolves.toEqual([]);
    await expectApiError(provider.exams('fictional-token'), 'ACADEMIC_UPSTREAM_CHANGED');
  });

  it('normalizes documented string and number variants through the DTO allowlist', async () => {
    vi.spyOn(globalThis, 'fetch').mockResolvedValue(
      jsonResponse({
        code: 1,
        data: [{ semesterId: 202601, semesterName: '虚构学期', nowXq: 1 }],
      }),
    );
    await expect(new RealAcademicProvider().semesters('fictional-token')).resolves.toEqual([
      { id: '202601', name: '虚构学期', current: true },
    ]);
  });

  it('merges a synthetic normal and experiment week with stable DTO fields', async () => {
    const provider = new RealAcademicProvider();
    const courses = provider.mapWeek(
      {
        normal: (await fixture('week-normal.json')) as Record<string, unknown>,
        experiment: (await fixture('week-experiment.json')) as Record<string, unknown>,
      },
      'fictional-semester',
    );
    expect(courses['2026-09-07']).toHaveLength(2);
    expect(courses['2026-09-08']).toEqual([]);
    expect(courses['2026-09-07']?.map(({ isExperiment }) => isExperiment)).toEqual([false, true]);
    expect(courses['2026-09-07']?.every(({ id }) => id.length > 0)).toBe(true);
  });

  it('accepts a completely empty timetable and anchors it with the reported current week', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-19T04:00:00Z'));
    vi.spyOn(globalThis, 'fetch').mockImplementation((input) => {
      const path = new URL(String(input)).pathname;
      if (path.endsWith('/teachingWeek'))
        return Promise.resolve(
          jsonResponse({ nowWeek: '3', data: [{ week: '1' }, { week: 2 }, { week: '3' }] }),
        );
      if (path.endsWith('/semesterList'))
        return Promise.resolve(
          jsonResponse({
            data: [{ semesterId: 'fictional-semester', semesterName: '虚构学期', nowXq: '1' }],
          }),
        );
      return Promise.resolve(jsonResponse({ data: [] }));
    });

    const timetable = await new RealAcademicProvider().refreshTimetable('fictional-token');

    expect(timetable).toMatchObject({
      firstWeek: 1,
      maxWeek: 3,
      firstDay: '2026-08-03',
      coursesByDate: {},
    });
    vi.useRealTimers();
  });

  it('verifies a historical semester with the documented xnxq01id query', async () => {
    const normal = await fixture('week-normal.json');
    const experiment = await fixture('week-experiment.json');
    const fetchMock = vi.spyOn(globalThis, 'fetch').mockImplementation((input) => {
      const url = new URL(String(input));
      if (url.pathname.endsWith('/teachingWeek'))
        return Promise.resolve(jsonResponse({ nowWeek: 1, data: [{ week: 1 }] }));
      if (url.pathname.endsWith('/student/curriculum'))
        return Promise.resolve(jsonResponse(normal));
      return Promise.resolve(jsonResponse(experiment));
    });

    const summary = await new RealAcademicProvider().verifyHistoricalTimetable(
      'fictional-token',
      'fictional-semester',
    );

    expect(summary).toEqual({
      semesterId: 'fictional-semester',
      days: 2,
      courses: 2,
      normalCourses: 1,
      experimentCourses: 1,
    });
    const curriculumUrl = fetchMock.mock.calls
      .map(([input]) => new URL(String(input)))
      .find(({ pathname }) => pathname.endsWith('/student/curriculum'));
    expect(curriculumUrl?.searchParams.get('xnxq01id')).toBe('fictional-semester');
    expect(curriculumUrl?.searchParams.get('week')).toBe('1');
  });

  it('skips malformed classTime and keeps parsing valid courses', () => {
    const provider = new RealAcademicProvider();
    const result = provider.mapWeek(
      {
        normal: {
          data: [
            {
              date: [
                { mxrq: '2026-09-07', xqid: 1 },
                { mxrq: '2026-09-08', xqid: 2 },
              ],
              item: [
                { classTime: 'bad', courseName: '坏数据' },
                { classTime: '1', courseName: '太短' },
                {
                  classTime: '10102',
                  courseName: '离散数学',
                  teacherName: '测试教师',
                  classWeek: '1-16',
                  location: '测试楼 101',
                },
              ],
            },
          ],
        },
        experiment: { data: [] },
      },
      'fictional-semester',
    );
    expect(result['2026-09-07']).toHaveLength(1);
    expect(result['2026-09-07']?.[0]?.name).toBe('离散数学');
  });

  it('parses free room seat count and occupied slots from zyjc', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation((input) => {
      const url = new URL(String(input));
      if (url.pathname.endsWith('/currentTerm'))
        return Promise.resolve(jsonResponse({ data: [{ semesterId: 'fictional-semester' }] }));
      return Promise.resolve(
        jsonResponse({
          data: [
            { classroomId: 'c1', classroomname: '101', seatnumber: '60', zyjc: '10102,10304' },
            { classroomId: 'c2', classroomname: '203', seatnumber: '48', zyjc: '' },
          ],
        }),
      );
    });

    const rooms = await new RealAcademicProvider().freeRooms('fictional-token', {
      date: '2026-09-07',
      nodeId: '0102',
      buildingId: 'public',
    });

    expect(rooms).toEqual([
      { id: 'c1', name: '101', seatNumber: '60', occupied: ['0102', '0304'] },
      { id: 'c2', name: '203', seatNumber: '48', occupied: ['00'] },
    ]);
  });
});

describe('isValidNodeId', () => {
  it('accepts valid 1-12 lesson ranges and rejects invalid ones', () => {
    expect(isValidNodeId('0102')).toBe(true);
    expect(isValidNodeId('0112')).toBe(true);
    expect(isValidNodeId('1212')).toBe(true);
    expect(isValidNodeId('0201')).toBe(false);
    expect(isValidNodeId('0012')).toBe(false);
    expect(isValidNodeId('0113')).toBe(false);
    expect(isValidNodeId('010')).toBe(false);
    expect(isValidNodeId('abcd')).toBe(false);
  });
});
