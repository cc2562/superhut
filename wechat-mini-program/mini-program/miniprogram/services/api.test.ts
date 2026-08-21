import { beforeEach, describe, expect, it, vi } from 'vitest';
import { api, ClientApiError, ensureWechatSession, toastRequestError } from './api';

interface CallRecord {
  path: string;
  method: string;
  header: Record<string, string>;
  data: unknown;
}
type Outcome = { statusCode: number; data: unknown } | { fail: unknown };

const store = new Map<string, unknown>();
const calls: CallRecord[] = [];
const showToast = vi.fn();
const navigateTo = vi.fn();
let respond: (call: CallRecord) => Outcome = () => ({ statusCode: 500, data: {} });

const ok = (data: unknown, requestId = 'req-1') => ({
  statusCode: 200,
  data: { data, meta: { requestId } },
});
const apiError = (statusCode: number, code: string, requestId = 'req-err') => ({
  statusCode,
  data: { error: { code, message: '错误', requestId } },
});

const timetable = {
  semesterId: '2025-2026-2-1',
  firstWeek: 1,
  maxWeek: 20,
  firstDay: '2026-02-23',
  coursesByDate: {},
};
const credentialRecord = {
  schemaVersion: 1,
  studentId: '2300000001',
  password: 'fixture-only',
  savedAt: new Date().toISOString(),
  expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
};

beforeEach(() => {
  store.clear();
  calls.length = 0;
  showToast.mockClear();
  navigateTo.mockClear();
  respond = () => ({ statusCode: 500, data: {} });
  vi.stubGlobal('getApp', () => ({
    globalData: { cloudEnvId: 'test-env', cloudService: 'superhut-api' },
  }));
  vi.stubGlobal('wx', {
    showToast,
    navigateTo,
    getStorageSync: (key: string) => store.get(key) ?? '',
    setStorageSync: (key: string, value: unknown) => void store.set(key, value),
    removeStorageSync: (key: string) => void store.delete(key),
    getStorage: async (options: { key: string }) => {
      if (!store.has(options.key)) throw new Error('missing key');
      return { data: store.get(options.key) };
    },
    setStorage: async (options: { key: string; data: unknown }) =>
      void store.set(options.key, options.data),
    removeStorage: async (options: { key: string }) => void store.delete(options.key),
    cloud: {
      callContainer: (options: {
        path: string;
        method: string;
        header: Record<string, string>;
        data: unknown;
        success: (result: { statusCode: number; data: unknown }) => void;
        fail: (error: unknown) => void;
      }) => {
        const record: CallRecord = {
          path: options.path,
          method: options.method,
          header: options.header,
          data: options.data,
        };
        calls.push(record);
        const outcome = respond(record);
        setTimeout(() => {
          if ('fail' in outcome) options.fail(outcome.fail);
          else options.success(outcome);
        }, 0);
      },
    },
  } as unknown as typeof wx);
});

describe('client api request layer', () => {
  it('sends cloud service headers and bearer token for authenticated calls', async () => {
    store.set('session_access_v1', 'access-1');
    respond = () => ok(timetable);
    const response = await api.timetable();
    expect(response.data.semesterId).toBe('2025-2026-2-1');
    expect(calls).toHaveLength(1);
    expect(calls[0]?.header['X-WX-SERVICE']).toBe('superhut-api');
    expect(calls[0]?.header.Authorization).toBe('Bearer access-1');
  });

  it('refreshes the session once and retries after AUTH_REQUIRED', async () => {
    store.set('session_access_v1', 'stale-access');
    store.set('session_refresh_v1', 'refresh-1');
    respond = (call) => {
      if (call.path === '/v1/auth/refresh')
        return ok({ accessToken: 'access-2', refreshToken: 'refresh-2', expiresIn: 900 });
      const timetableCalls = calls.filter((item) => item.path === '/v1/academic/timetable');
      return timetableCalls.length === 1 ? apiError(401, 'AUTH_REQUIRED') : ok(timetable);
    };
    const response = await api.timetable();
    expect(response.data.semesterId).toBe('2025-2026-2-1');
    expect(store.get('session_access_v1')).toBe('access-2');
    expect(store.get('session_refresh_v1')).toBe('refresh-2');
    expect(calls.map((call) => call.path)).toEqual([
      '/v1/academic/timetable',
      '/v1/auth/refresh',
      '/v1/academic/timetable',
    ]);
    expect(calls[1]?.method).toBe('POST');
    expect(calls[1]?.data).toEqual({ refreshToken: 'refresh-1' });
  });

  it('surfaces AUTH_REQUIRED when no refresh token is stored', async () => {
    store.set('session_access_v1', 'stale-access');
    respond = () => apiError(401, 'AUTH_REQUIRED');
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' });
    expect(calls).toHaveLength(1);
  });

  it('propagates refresh failure instead of retrying', async () => {
    store.set('session_refresh_v1', 'refresh-1');
    respond = () => apiError(401, 'AUTH_REQUIRED');
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' });
    expect(calls.filter((call) => call.path === '/v1/auth/refresh')).toHaveLength(1);
    expect(calls.filter((call) => call.path === '/v1/academic/timetable')).toHaveLength(1);
    expect(store.has('session_refresh_v1')).toBe(false);
  });

  it('does not refresh again when the retried request still returns AUTH_REQUIRED', async () => {
    store.set('session_refresh_v1', 'refresh-1');
    respond = (call) =>
      call.path === '/v1/auth/refresh'
        ? ok({ accessToken: 'access-2', refreshToken: 'refresh-2', expiresIn: 900 })
        : apiError(401, 'AUTH_REQUIRED');
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' });
    expect(calls.filter((call) => call.path === '/v1/auth/refresh')).toHaveLength(1);
    expect(calls.filter((call) => call.path === '/v1/academic/timetable')).toHaveLength(2);
  });

  it('rebuilds the WeChat session automatically when refresh fails', async () => {
    store.set('session_access_v1', 'stale-access');
    store.set('session_refresh_v1', 'expired-refresh');
    store.set('privacy_consent_v1', '2026-08-18');
    respond = (call) => {
      if (call.path === '/v1/auth/refresh') return apiError(401, 'AUTH_REQUIRED');
      if (call.path === '/v1/auth/wechat/login')
        return ok({
          accessToken: 'access-3',
          refreshToken: 'refresh-3',
          expiresIn: 900,
          academicBinding: { status: 'active' },
        });
      const timetableCalls = calls.filter((item) => item.path === '/v1/academic/timetable');
      return timetableCalls.length === 1 ? apiError(401, 'AUTH_REQUIRED') : ok(timetable);
    };
    const response = await api.timetable();
    expect(response.data.semesterId).toBe('2025-2026-2-1');
    expect(store.get('session_access_v1')).toBe('access-3');
    expect(store.get('session_refresh_v1')).toBe('refresh-3');
    expect(calls.map((call) => call.path)).toEqual([
      '/v1/academic/timetable',
      '/v1/auth/refresh',
      '/v1/auth/wechat/login',
      '/v1/academic/timetable',
    ]);
    expect(calls[2]?.data).toEqual({ privacyConsentVersion: '2026-08-18' });
  });

  it('does not rebuild the session when there is no access token', async () => {
    store.set('privacy_consent_v1', '2026-08-18');
    respond = () => apiError(401, 'AUTH_REQUIRED');
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' });
    expect(calls.map((call) => call.path)).toEqual(['/v1/academic/timetable']);
  });

  it('keeps AUTH_REQUIRED when the WeChat relogin also fails', async () => {
    store.set('session_access_v1', 'stale-access');
    store.set('session_refresh_v1', 'expired-refresh');
    store.set('privacy_consent_v1', '2026-08-18');
    respond = (call) => {
      if (call.path === '/v1/auth/refresh') return apiError(401, 'AUTH_REQUIRED');
      if (call.path === '/v1/auth/wechat/login')
        return apiError(503, 'ACADEMIC_UPSTREAM_UNAVAILABLE');
      return apiError(401, 'AUTH_REQUIRED');
    };
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_REQUIRED' });
    expect(calls.map((call) => call.path)).toEqual([
      '/v1/academic/timetable',
      '/v1/auth/refresh',
      '/v1/auth/wechat/login',
    ]);
  });

  it('rebinds the academic account automatically after expiry', async () => {
    store.set('session_access_v1', 'access-1');
    store.set('academic_credentials_v1', credentialRecord);
    respond = (call) => {
      if (call.path === '/v1/auth/academic/login')
        return ok({ academicBinding: { status: 'active' } });
      const timetableCalls = calls.filter((item) => item.path === '/v1/academic/timetable');
      return timetableCalls.length === 1 ? apiError(401, 'AUTH_ACADEMIC_EXPIRED') : ok(timetable);
    };
    const response = await api.timetable();
    expect(response.data.semesterId).toBe('2025-2026-2-1');
    expect(calls.map((call) => call.path)).toEqual([
      '/v1/academic/timetable',
      '/v1/auth/academic/login',
      '/v1/academic/timetable',
    ]);
    expect(calls[1]?.data).toEqual({ studentId: '2300000001', password: 'fixture-only' });
  });

  it('drops the saved credential when rebind reports invalid credentials', async () => {
    store.set('session_access_v1', 'access-1');
    store.set('academic_credentials_v1', credentialRecord);
    respond = (call) => {
      if (call.path === '/v1/auth/academic/login')
        return apiError(400, 'AUTH_ACADEMIC_INVALID_CREDENTIALS');
      return apiError(401, 'AUTH_ACADEMIC_EXPIRED');
    };
    await expect(api.timetable()).rejects.toMatchObject({
      code: 'AUTH_ACADEMIC_INVALID_CREDENTIALS',
    });
    expect(store.has('academic_credentials_v1')).toBe(false);
  });

  it('rejects AUTH_ACADEMIC_EXPIRED when no credential is saved', async () => {
    respond = () => apiError(401, 'AUTH_ACADEMIC_EXPIRED');
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_ACADEMIC_EXPIRED' });
    expect(calls).toHaveLength(1);
  });

  it('rejects AUTH_ACADEMIC_EXPIRED when the saved credential is expired', async () => {
    store.set('academic_credentials_v1', {
      ...credentialRecord,
      expiresAt: new Date(Date.now() - 1_000).toISOString(),
    });
    respond = () => apiError(401, 'AUTH_ACADEMIC_EXPIRED');
    await expect(api.timetable()).rejects.toMatchObject({ code: 'AUTH_ACADEMIC_EXPIRED' });
    expect(calls).toHaveLength(1);
  });

  it('maps callContainer failures to NETWORK_ERROR', async () => {
    respond = () => ({ fail: new Error('connection dropped') });
    await expect(api.exams()).rejects.toMatchObject({ code: 'NETWORK_ERROR' });
    expect(calls).toHaveLength(1);
  });

  it('exposes upstream error code and request id', async () => {
    respond = () => apiError(503, 'ACADEMIC_UPSTREAM_UNAVAILABLE', 'req-upstream');
    const rejection = await api.exams().then(
      () => undefined,
      (error: ClientApiError) => error,
    );
    expect(rejection).toBeInstanceOf(ClientApiError);
    expect(rejection?.code).toBe('ACADEMIC_UPSTREAM_UNAVAILABLE');
    expect(rejection?.requestId).toBe('req-upstream');
  });

  it('falls back to INTERNAL_ERROR when the payload has no error shape', async () => {
    respond = () => ({ statusCode: 502, data: 'upstream html' });
    await expect(api.exams()).rejects.toMatchObject({ code: 'INTERNAL_ERROR' });
  });

  it('clears timetable, session and credential on logout', async () => {
    store.set('session_access_v1', 'access-1');
    store.set('session_refresh_v1', 'refresh-1');
    store.set('timetable_snapshot_v1', { value: timetable, fetchedAt: '2026-08-20T00:00:00Z' });
    store.set('academic_credentials_v1', credentialRecord);
    respond = () => ok({ loggedOut: true });
    await api.logout();
    expect(store.has('session_access_v1')).toBe(false);
    expect(store.has('session_refresh_v1')).toBe(false);
    expect(store.has('timetable_snapshot_v1')).toBe(false);
    expect(store.has('academic_credentials_v1')).toBe(false);
  });

  it('creates a WeChat session on demand when none exists', async () => {
    store.set('privacy_consent_v1', '2026-08-18');
    respond = () =>
      ok({
        accessToken: 'access-9',
        refreshToken: 'refresh-9',
        expiresIn: 900,
        academicBinding: { status: 'unbound' },
      });
    await ensureWechatSession();
    expect(store.get('session_access_v1')).toBe('access-9');
    expect(store.get('session_refresh_v1')).toBe('refresh-9');
    expect(calls.map((call) => call.path)).toEqual(['/v1/auth/wechat/login']);
  });

  it('skips session creation when a token already exists', async () => {
    store.set('session_access_v1', 'access-1');
    respond = () => apiError(500, 'INTERNAL_ERROR');
    await ensureWechatSession();
    expect(calls).toHaveLength(0);
  });
});

describe('toastRequestError', () => {
  it('prompts and navigates to login on AUTH_ACADEMIC_EXPIRED', () => {
    vi.useFakeTimers();
    toastRequestError(
      new ClientApiError('AUTH_ACADEMIC_EXPIRED', '教务登录状态已失效，请重新登录'),
      '加载失败',
    );
    expect(showToast).toHaveBeenCalledWith(
      expect.objectContaining({ title: '教务登录已过期，请重新登录' }),
    );
    vi.runAllTimers();
    expect(navigateTo).toHaveBeenCalledWith({ url: '/pages/login/index' });
    vi.useRealTimers();
  });

  it('shows a plain toast for other errors without navigating', () => {
    toastRequestError(
      new ClientApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', '学校服务器不可用'),
      '加载失败',
    );
    expect(showToast).toHaveBeenCalledWith(expect.objectContaining({ title: '学校服务器不可用' }));
    expect(navigateTo).not.toHaveBeenCalled();
  });
});
