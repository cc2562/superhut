import type {
  EvaluationBatch,
  EvaluationBatchRequest,
  EvaluationBatchResult,
  EvaluationItem,
  EvaluationItemRequest,
  EvaluationQuestion,
  EvaluationSubmitRequest,
  ScoresResponse,
  SuccessResponse,
  Timetable,
} from '@superhut/api-contract';
import { storage } from './storage';

interface SessionData {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  academicBinding: {
    status: 'active' | 'expired' | 'unbound';
    studentIdMasked?: string;
    displayName?: string;
  };
}
interface ApiErrorShape {
  error?: { code?: string; message?: string; requestId?: string };
}
export interface Stage0VerificationItem {
  key:
    'semesters' | 'timetable' | 'historicalTimetable' | 'scores' | 'exams' | 'buildings' | 'rooms';
  label: string;
  count: number;
  requestId: string;
}
export interface Stage0VerificationSummary {
  items: Stage0VerificationItem[];
  timetable: Timetable;
  timetableFetchedAt: string;
}
export class ClientApiError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly requestId = '',
  ) {
    super(message);
  }
}

export function toastRequestError(error: unknown, fallback: string): void {
  const message =
    error instanceof ClientApiError && error.code === 'AUTH_REQUIRED'
      ? '请先登录教务账号'
      : error instanceof Error
        ? error.message
        : fallback;
  wx.showToast({ title: message, icon: 'none', duration: 3000 });
}

interface CallContainerResult<T> {
  statusCode: number;
  data: T;
}
interface CallContainerApi {
  callContainer<T>(options: {
    config: { env: string };
    path: string;
    method: WechatMiniprogram.RequestOption['method'];
    data: WechatMiniprogram.IAnyObject;
    header: Record<string, string>;
    timeout: number;
    success: (result: CallContainerResult<T>) => void;
    fail: (error: unknown) => void;
  }): void;
}
async function createWechatSession(): Promise<void> {
  const privacyConsentVersion = storage.privacyAccepted();
  if (!privacyConsentVersion)
    throw new ClientApiError('PRIVACY_CONSENT_REQUIRED', '请先同意隐私指引');
  const session = await request<SessionData>('/v1/auth/wechat/login', {
    method: 'POST',
    data: { privacyConsentVersion },
  });
  storage.saveSession(session.data.accessToken, session.data.refreshToken);
}

export async function ensureWechatSession(): Promise<void> {
  if (!storage.accessToken()) await createWechatSession();
}

async function recoverWechatSession(hadAccessToken: boolean): Promise<boolean> {
  const refreshToken = storage.refreshToken();
  if (refreshToken) {
    try {
      const refreshed = await request<{ accessToken: string; refreshToken: string }>(
        '/v1/auth/refresh',
        { method: 'POST', data: { refreshToken }, retried: true },
      );
      storage.saveSession(refreshed.data.accessToken, refreshed.data.refreshToken);
      return true;
    } catch {
      storage.clearSession();
    }
  }
  if (!hadAccessToken) return false;
  try {
    await createWechatSession();
    return true;
  } catch {
    return false;
  }
}

async function request<T>(
  path: string,
  options: {
    method?: WechatMiniprogram.RequestOption['method'];
    data?: unknown;
    authenticated?: boolean;
    retried?: boolean;
  } = {},
): Promise<SuccessResponse<T>> {
  const token = storage.accessToken();
  try {
    const app = getApp<IAppOption>();
    const response = await new Promise<CallContainerResult<SuccessResponse<T> | ApiErrorShape>>(
      (resolve, reject) => {
        (wx.cloud as unknown as CallContainerApi).callContainer<SuccessResponse<T> | ApiErrorShape>(
          {
            config: { env: app.globalData.cloudEnvId },
            path,
            method: options.method ?? 'GET',
            data: (options.data ?? {}) as WechatMiniprogram.IAnyObject,
            header: {
              'X-WX-SERVICE': app.globalData.cloudService,
              'content-type': 'application/json',
              ...(options.authenticated && token ? { Authorization: `Bearer ${token}` } : {}),
            },
            timeout: 20_000,
            success: resolve,
            fail: reject,
          },
        );
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300 && 'data' in response.data)
      return response.data as SuccessResponse<T>;
    const error = (response.data as ApiErrorShape).error;
    if (
      response.statusCode === 401 &&
      error?.code === 'AUTH_REQUIRED' &&
      options.authenticated &&
      !options.retried
    ) {
      if (await recoverWechatSession(Boolean(token))) {
        return request(path, { ...options, retried: true });
      }
    }
    if (error?.code === 'AUTH_ACADEMIC_EXPIRED' && options.authenticated && !options.retried) {
      const credential = await storage.credential();
      if (credential) {
        try {
          await request('/v1/auth/academic/login', {
            method: 'POST',
            data: { studentId: credential.studentId, password: credential.password },
            authenticated: true,
            retried: true,
          });
          return request(path, { ...options, retried: true });
        } catch (loginError) {
          if (
            loginError instanceof ClientApiError &&
            loginError.code === 'AUTH_ACADEMIC_INVALID_CREDENTIALS'
          ) {
            await storage.deleteCredential();
          }
          throw loginError;
        }
      }
    }
    throw new ClientApiError(
      error?.code ?? 'INTERNAL_ERROR',
      error?.message ?? '服务暂时不可用',
      error?.requestId,
    );
  } catch (error) {
    if (error instanceof ClientApiError) throw error;
    throw new ClientApiError('NETWORK_ERROR', '网络连接失败，请稍后重试');
  }
}

export const api = {
  async wechatLogin(privacyConsentVersion: string): Promise<SessionData> {
    return (
      await request<SessionData>('/v1/auth/wechat/login', {
        method: 'POST',
        data: { privacyConsentVersion },
      })
    ).data;
  },
  async academicLogin(studentId: string, password: string) {
    return (
      await request<{ academicBinding: SessionData['academicBinding'] }>(
        '/v1/auth/academic/login',
        { method: 'POST', data: { studentId, password }, authenticated: true },
      )
    ).data;
  },
  async status() {
    return (
      await request<{ academicBinding: SessionData['academicBinding'] }>(
        '/v1/auth/academic/status',
        { authenticated: true },
      )
    ).data;
  },
  async timetable() {
    return request<Timetable>('/v1/academic/timetable', { authenticated: true });
  },
  async refreshTimetable() {
    return request<Timetable>('/v1/academic/timetable/refresh', {
      method: 'POST',
      authenticated: true,
    });
  },
  async semesters() {
    return (
      await request<Array<{ id: string; name: string; current: boolean }>>(
        '/v1/academic/semesters',
        { authenticated: true },
      )
    ).data;
  },
  async scores(semesterId: string) {
    return (
      await request<ScoresResponse>(
        `/v1/academic/scores?semesterId=${encodeURIComponent(semesterId)}`,
        { authenticated: true },
      )
    ).data;
  },
  async exams() {
    return (
      await request<Array<Record<string, unknown>>>('/v1/academic/exams', { authenticated: true })
    ).data;
  },
  async buildings() {
    return (
      await request<Array<{ id: string; name: string }>>('/v1/academic/rooms/buildings', {
        authenticated: true,
      })
    ).data;
  },
  async rooms(date: string, nodeId: string, buildingId: string) {
    return (
      await request<Array<{ id: string; name: string }>>(
        `/v1/academic/rooms/free?date=${encodeURIComponent(date)}&nodeId=${encodeURIComponent(nodeId)}&buildingId=${encodeURIComponent(buildingId)}`,
        { authenticated: true },
      )
    ).data;
  },
  async stage0VerifyQueries(): Promise<Stage0VerificationSummary> {
    const items: Stage0VerificationItem[] = [];
    const semesters = await request<Array<{ id: string; name: string; current: boolean }>>(
      '/v1/academic/semesters',
      { authenticated: true },
    );
    items.push({
      key: 'semesters',
      label: '学期',
      count: semesters.data.length,
      requestId: semesters.meta.requestId,
    });
    const semester = semesters.data.find(({ current }) => current) ?? semesters.data[0];
    if (!semester)
      throw new ClientApiError(
        'ACADEMIC_UPSTREAM_CHANGED',
        '没有可用于继续验证的学期',
        semesters.meta.requestId,
      );

    const timetable = await request<Timetable>('/v1/academic/timetable/refresh', {
      method: 'POST',
      authenticated: true,
    });
    const courseCount = Object.values(timetable.data.coursesByDate).reduce(
      (total, courses) => total + courses.length,
      0,
    );
    items.push({
      key: 'timetable',
      label: '课表',
      count: courseCount,
      requestId: timetable.meta.requestId,
    });
    if (courseCount === 0) {
      const currentIndex = semesters.data.findIndex(({ id }) => id === semester.id);
      const historicalSemester = semesters.data
        .slice(Math.max(0, currentIndex + 1))
        .find(({ id, current }) => !current && /-[12]$/.test(id));
      if (!historicalSemester)
        throw new ClientApiError(
          'ACADEMIC_UPSTREAM_CHANGED',
          '当前课表为空，且没有可用于验证的历史学期',
          timetable.meta.requestId,
        );
      const historical = await request<{
        semesterId: string;
        days: number;
        courses: number;
        normalCourses: number;
        experimentCourses: number;
      }>(
        `/_stage0/academic/historical-timetable?semesterId=${encodeURIComponent(historicalSemester.id)}`,
        { authenticated: true },
      );
      if (historical.data.courses === 0)
        throw new ClientApiError(
          'ACADEMIC_UPSTREAM_CHANGED',
          '学校接口未返回可用于验证的上学期课程',
          historical.meta.requestId,
        );
      items.push({
        key: 'historicalTimetable',
        label: '上学期课表',
        count: historical.data.courses,
        requestId: historical.meta.requestId,
      });
    }

    const scores = await request<ScoresResponse>(
      `/v1/academic/scores?semesterId=${encodeURIComponent(semester.id)}`,
      { authenticated: true },
    );
    items.push({
      key: 'scores',
      label: '成绩',
      count: scores.data.scores.length,
      requestId: scores.meta.requestId,
    });

    const exams = await request<Array<Record<string, unknown>>>('/v1/academic/exams', {
      authenticated: true,
    });
    items.push({
      key: 'exams',
      label: '考试',
      count: exams.data.length,
      requestId: exams.meta.requestId,
    });

    const buildings = await request<Array<{ id: string; name: string }>>(
      '/v1/academic/rooms/buildings',
      { authenticated: true },
    );
    items.push({
      key: 'buildings',
      label: '教学楼',
      count: buildings.data.length,
      requestId: buildings.meta.requestId,
    });
    const building = buildings.data[0];
    if (building) {
      const now = new Date();
      const date = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
      const rooms = await request<Array<{ id: string; name: string }>>(
        `/v1/academic/rooms/free?date=${date}&nodeId=0102&buildingId=${encodeURIComponent(building.id)}`,
        { authenticated: true },
      );
      items.push({
        key: 'rooms',
        label: '空教室',
        count: rooms.data.length,
        requestId: rooms.meta.requestId,
      });
    }
    return {
      items,
      timetable: timetable.data,
      timetableFetchedAt: timetable.meta.fetchedAt ?? new Date().toISOString(),
    };
  },
  async logout() {
    await request('/v1/auth/logout', { method: 'POST', authenticated: true });
    storage.clearSession();
    storage.clearTimetable();
    await storage.deleteCredential();
  },
  async unbind() {
    await request('/v1/auth/academic/binding', { method: 'DELETE', authenticated: true });
    storage.clearTimetable();
    await storage.deleteCredential();
  },
  async deleteAccount() {
    await request('/v1/me', { method: 'DELETE', authenticated: true });
    await storage.clearAll();
  },
  async evaluationBatches() {
    return (
      await request<EvaluationBatch[]>('/v1/academic/evaluation/batches', { authenticated: true })
    ).data;
  },
  async evaluationList(batch: EvaluationBatchRequest) {
    const query = `batchId=${encodeURIComponent(batch.batchId)}&pj01id=${encodeURIComponent(batch.pj01id)}&pj05id=${encodeURIComponent(batch.pj05id)}`;
    return (
      await request<EvaluationItem[]>(`/v1/academic/evaluation/list?${query}`, {
        authenticated: true,
      })
    ).data;
  },
  async evaluationQuestions(item: EvaluationItemRequest) {
    const query = `batchId=${encodeURIComponent(item.batchId)}&evaluationCategoriesId=${encodeURIComponent(item.evaluationCategoriesId)}&courseId=${encodeURIComponent(item.courseId)}&teacherId=${encodeURIComponent(item.teacherId)}&noticeId=${encodeURIComponent(item.noticeId)}`;
    return (
      await request<EvaluationQuestion[]>(`/v1/academic/evaluation/questions?${query}`, {
        authenticated: true,
      })
    ).data;
  },
  async submitEvaluation(submission: EvaluationSubmitRequest) {
    return (
      await request<{ submitted: boolean }>('/v1/academic/evaluation/submit', {
        method: 'POST',
        data: submission,
        authenticated: true,
      })
    ).data;
  },
  async autoSubmitEvaluation(item: EvaluationItemRequest) {
    return (
      await request<{ submitted: boolean }>('/v1/academic/evaluation/auto', {
        method: 'POST',
        data: item,
        authenticated: true,
      })
    ).data;
  },
  async autoSubmitAll(batch: EvaluationBatchRequest) {
    return (
      await request<EvaluationBatchResult>('/v1/academic/evaluation/auto-all', {
        method: 'POST',
        data: batch,
        authenticated: true,
      })
    ).data;
  },
};
