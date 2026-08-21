import { Injectable } from '@nestjs/common';
import { createCipheriv } from 'node:crypto';
import type { Course, Timetable } from '@superhut/api-contract';
import { stableCourseId } from '@superhut/domain-rules';
import { environment } from '../config.js';
import { ApiError } from '../common/api-error.js';
import type {
  AcademicAccount,
  AcademicProvider,
  BuildingDto,
  EvaluationBatchDto,
  EvaluationItemDto,
  EvaluationQuestionDto,
  EvaluationSubmissionDto,
  ExamDto,
  FreeRoomDto,
  ScoresResultDto,
  SemesterDto,
} from './academic-provider.js';

type JsonObject = Record<string, unknown>;
type UpstreamAuth = 'login' | 'token' | 'none';

interface WeekPayloads {
  normal: JsonObject;
  experiment: JsonObject;
}

export interface Stage0TimetableSummary {
  semesterId: string;
  days: number;
  courses: number;
  normalCourses: number;
  experimentCourses: number;
}

const asObject = (value: unknown): JsonObject => {
  if (typeof value !== 'object' || value === null || Array.isArray(value))
    throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务系统正在维护');
  return value as JsonObject;
};
const asArray = (value: unknown): unknown[] => {
  if (!Array.isArray(value))
    throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务系统正在维护');
  return value;
};
const text = (value: unknown): string =>
  value === null || value === undefined ? '' : String(value);
const numberValue = (value: unknown): number | null => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};
// zyjc 为逗号分隔的占用节次区间，每段去掉首字符得到形如 "0102" 的区间；空串表示全天空闲。
const occupiedFromZyJc = (value: unknown): string[] => {
  const raw = text(value);
  if (!raw) return ['00'];
  return raw
    .split(',')
    .map((segment) => (segment.length <= 2 ? '' : segment.slice(1)))
    .filter((segment) => segment.length > 0);
};

const isFailureCode = (value: unknown): boolean =>
  value === 0 || value === '0' || value === -1 || value === '-1' || value === false;

const isSuccessCode = (value: unknown): boolean => value === 1 || value === '1' || value === true;

const semesterFirstDayFromCurrentWeek = (currentWeek: number, now = new Date()): string => {
  const today = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
  const date = new Date(`${today}T00:00:00Z`);
  const weekday = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() - (weekday - 1) - (currentWeek - 1) * 7);
  return date.toISOString().slice(0, 10);
};

// 带并发上限地 map：并发调用 fn 但结果按原顺序返回。用于课表刷新时并发拉取多周，
// 避免串行 20 周 × 2 请求把总耗时拖到客户端超时（历史课表数据多时尤其明显）。
const mapConcurrent = async <T, R>(
  items: readonly T[],
  concurrency: number,
  fn: (item: T) => Promise<R>,
): Promise<R[]> => {
  const results: R[] = new Array(items.length);
  let next = 0;
  const workers = Array.from(
    { length: Math.min(Math.max(1, concurrency), items.length) },
    async () => {
      while (next < items.length) {
        const index = next;
        next += 1;
        const item = items[index];
        if (item === undefined) break;
        results[index] = await fn(item);
      }
    },
  );
  await Promise.all(workers);
  return results;
};

@Injectable()
export class RealAcademicProvider implements AcademicProvider {
  private readonly baseUrl = environment().HUT_ACADEMIC_BASE_URL;
  private passwordParameter(password: string): string {
    const key = Buffer.alloc(16);
    Buffer.from(environment().ACADEMIC_PASSWORD_KEY, 'utf8').copy(key, 0, 0, 16);
    const cipher = createCipheriv('aes-128-ecb', key, null);
    cipher.setAutoPadding(true);
    const encrypted = Buffer.concat([
      cipher.update(JSON.stringify(password), 'utf8'),
      cipher.final(),
    ]).toString('base64');
    return Buffer.from(encrypted, 'utf8').toString('base64');
  }
  private async post(
    path: string,
    options: { token?: string; auth?: UpstreamAuth; body?: unknown } = {},
  ): Promise<JsonObject> {
    let response: Response;
    try {
      response = await fetch(new URL(path, this.baseUrl), {
        method: 'POST',
        headers: {
          Accept: '*/*',
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
          ...(options.token ? { Token: options.token } : {}),
          ...(options.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(options.body !== undefined ? { body: JSON.stringify(options.body) } : {}),
        signal: AbortSignal.timeout(20_000),
      });
    } catch {
      throw new ApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', 503, '学校服务器不可用');
    }
    if (response.status === 429)
      throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '请求较频繁，请稍后重试');
    if (!response.ok) {
      if (options.auth === 'token' && response.status >= 500) {
        const contentType = response.headers.get('content-type') ?? '';
        if (contentType.includes('json')) {
          try {
            const failure = asObject(await response.json());
            if (failure.code === 401 || failure.code === '401')
              throw new ApiError('AUTH_ACADEMIC_EXPIRED', 401, '教务登录状态已失效，请重新登录');
          } catch (error) {
            if (error instanceof ApiError && error.code === 'AUTH_ACADEMIC_EXPIRED') throw error;
          }
        }
        throw new ApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', 503, '学校服务器不可用');
      }
      if (response.status >= 500)
        throw new ApiError('ACADEMIC_UPSTREAM_UNAVAILABLE', 503, '学校服务器不可用');
      if (options.auth === 'login' && [400, 401, 403].includes(response.status))
        throw new ApiError(
          'AUTH_ACADEMIC_INVALID_CREDENTIALS',
          401,
          '账号、密码或学校服务状态异常，请检查后重试',
        );
      if (options.auth === 'token' && [401, 403].includes(response.status))
        throw new ApiError('AUTH_ACADEMIC_EXPIRED', 401, '教务登录状态已失效，请重新登录');
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务系统正在维护');
    }
    const contentType = response.headers.get('content-type') ?? '';
    if (!contentType.includes('json'))
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务系统正在维护');
    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务系统正在维护');
    }
    return asObject(payload);
  }
  async login(studentId: string, password: string): Promise<AcademicAccount> {
    const query = new URLSearchParams({ userNo: studentId, pwd: this.passwordParameter(password) });
    const payload = await this.post(`/njwhd/login?${query.toString()}`, { auth: 'login' });
    if (isFailureCode(payload.code) || payload.success === false)
      throw new ApiError(
        'AUTH_ACADEMIC_INVALID_CREDENTIALS',
        401,
        '账号、密码或学校服务状态异常，请检查后重试',
      );
    const data = asObject(payload.data);
    const token = text(data.token);
    if (!token) throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务登录响应格式发生变化');
    return {
      token,
      displayName: text(data.name),
      academyName: text(data.academyName),
      className: text(data.clsName),
      entranceYear: text(data.entranceYear),
    };
  }
  async validateToken(token: string): Promise<boolean> {
    try {
      const payload = await this.post('/njwhd/noticeTab', { token, auth: 'token' });
      if (isSuccessCode(payload.code)) return true;
      if (isFailureCode(payload.code)) return false;
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务 Token 校验格式发生变化');
    } catch (error) {
      if (error instanceof ApiError && error.code === 'AUTH_ACADEMIC_EXPIRED') return false;
      throw error;
    }
  }
  async semesters(token: string): Promise<SemesterDto[]> {
    const payload = await this.post('/njwhd/semesterList', { token, auth: 'token' });
    return asArray(payload.data ?? []).map((item) => {
      const row = asObject(item);
      return {
        id: text(row.semesterId),
        name: text(row.semesterName || row.xnxqmc),
        current: text(row.nowXq) === '1',
      };
    });
  }
  async refreshTimetable(token: string, semesterId = ''): Promise<Timetable> {
    const teaching = await this.post('/njwhd/teachingWeek', { token, auth: 'token' });
    const weeks = asArray(teaching.data)
      .map((item) => Number(asObject(item).week))
      .filter(Number.isInteger);
    if (!weeks.length)
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教学周数据格式发生变化');
    const firstWeek = Math.min(...weeks);
    const maxWeek = Math.max(...weeks);
    const currentWeek = Number(teaching.nowWeek);
    if (!Number.isInteger(currentWeek) || currentWeek < firstWeek || currentWeek > maxWeek)
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '当前教学周数据格式发生变化');
    const semesters = await this.semesters(token);
    const current = semesters.find(({ current }) => current) ?? semesters[0];
    const targetId = semesterId || current?.id || '';
    if (!targetId) throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '未找到当前学期');
    const historical = semesterId !== '';
    const weekNumbers: number[] = [];
    for (let week = firstWeek; week <= maxWeek; week += 1) weekNumbers.push(week);
    const payloads = await mapConcurrent(weekNumbers, 4, (week) =>
      this.fetchWeek(token, targetId, week, historical),
    );
    const coursesByDate: Record<string, Course[]> = {};
    let firstDay = '';
    weekNumbers.forEach((week, index) => {
      const weekPayloads = payloads[index];
      if (!weekPayloads) return;
      this.mapWeek(weekPayloads, targetId, coursesByDate);
      if (!firstDay) {
        const monday = Object.keys(coursesByDate).sort()[0];
        if (monday) {
          const date = new Date(`${monday}T00:00:00`);
          date.setDate(date.getDate() - (week - 1) * 7);
          firstDay = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
        }
      }
    });
    // A student can legitimately have no normal or experiment courses for the
    // whole term. In that case the authoritative teaching-week number still
    // provides the semester anchor without inventing course data.
    if (!firstDay) firstDay = semesterFirstDayFromCurrentWeek(currentWeek);
    return { semesterId: targetId, firstWeek, maxWeek, firstDay, coursesByDate };
  }

  async fetchWeek(
    token: string,
    semesterId: string,
    week: number,
    historical = false,
  ): Promise<WeekPayloads> {
    if (!Number.isInteger(week) || week < 1)
      throw new ApiError('VALIDATION_ERROR', 400, '教学周不正确');
    const normalPath = historical
      ? `/njwhd/student/curriculum?week=${week}&xnxq01id=${encodeURIComponent(semesterId)}`
      : `/njwhd/student/curriculum?week=${week}`;
    const [normal, experiment] = await Promise.all([
      this.post(normalPath, { token, auth: 'token' }),
      this.post(
        `/njwhd/teacher/courseScheduleExp?xnxq01id=${encodeURIComponent(semesterId)}&week=${week}`,
        { token, auth: 'token' },
      ),
    ]);
    return { normal, experiment };
  }

  async verifyHistoricalTimetable(
    token: string,
    semesterId: string,
  ): Promise<Stage0TimetableSummary> {
    if (!semesterId) throw new ApiError('VALIDATION_ERROR', 400, '用于验证的历史学期不正确');
    const teaching = await this.post('/njwhd/teachingWeek', { token, auth: 'token' });
    const weeks = asArray(teaching.data)
      .map((item) => Number(asObject(item).week))
      .filter(Number.isInteger);
    if (!weeks.length)
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教学周数据格式发生变化');
    const target: Record<string, Course[]> = {};
    for (let week = Math.min(...weeks); week <= Math.max(...weeks); week += 1) {
      const query = new URLSearchParams({ week: String(week), xnxq01id: semesterId });
      const [normal, experiment] = await Promise.all([
        this.post(`/njwhd/student/curriculum?${query.toString()}`, {
          token,
          auth: 'token',
        }),
        this.post(
          `/njwhd/teacher/courseScheduleExp?xnxq01id=${encodeURIComponent(semesterId)}&week=${week}`,
          { token, auth: 'token' },
        ),
      ]);
      this.mapWeek({ normal, experiment }, semesterId, target);
      if (Object.values(target).some((courses) => courses.length > 0)) break;
    }
    const courses = Object.values(target).flat();
    return {
      semesterId,
      days: Object.keys(target).length,
      courses: courses.length,
      normalCourses: courses.filter(({ isExperiment }) => !isExperiment).length,
      experimentCourses: courses.filter(({ isExperiment }) => isExperiment).length,
    };
  }

  mapWeek(
    payloads: WeekPayloads,
    semesterId: string,
    target: Record<string, Course[]> = {},
  ): Record<string, Course[]> {
    this.mapNormalWeek(payloads.normal, semesterId, target);
    this.mapExperimentWeek(payloads.experiment, semesterId, target);
    return target;
  }
  private mapNormalWeek(
    payload: JsonObject,
    semesterId: string,
    target: Record<string, Course[]>,
  ): void {
    const weeks = payload.data == null ? [] : asArray(payload.data);
    for (const rawWeek of weeks) {
      const week = asObject(rawWeek);
      const dates = asArray(week.date);
      const items = asArray(week.item);
      const byDay = new Map<number, string>();
      for (const rawDate of dates) {
        const row = asObject(rawDate);
        const date = text(row.mxrq);
        const weekday = Number(row.xqid);
        if (date && Number.isInteger(weekday)) {
          byDay.set(weekday, date);
          target[date] ??= [];
        }
      }
      for (const rawItem of items) {
        const row = asObject(rawItem);
        const classTime = text(row.classTime);
        if (classTime.length < 3) continue;
        const weekday = Number(classTime.slice(0, 1));
        const startSection = Number(classTime.slice(1, 3));
        const endSection = Number(classTime.slice(-2));
        if (
          !Number.isInteger(weekday) ||
          !Number.isInteger(startSection) ||
          !Number.isInteger(endSection)
        )
          continue;
        const date = byDay.get(weekday);
        if (!date) continue;
        const input = {
          name: text(row.courseName),
          teacherName: text(row.teacherName),
          weekDuration: text(row.classWeek),
          location: text(row.location),
          startSection,
          duration: endSection - startSection + 1,
          isExperiment: false,
        };
        target[date]?.push({ id: stableCourseId(semesterId, date, input), ...input });
      }
    }
  }
  private mapExperimentWeek(
    payload: JsonObject,
    semesterId: string,
    target: Record<string, Course[]>,
  ): void {
    const weeks = payload.data == null ? [] : asArray(payload.data);
    for (const rawWeek of weeks) {
      const week = asObject(rawWeek);
      const dates = asArray(week.date);
      const courses = asArray(week.courses ?? []);
      const byDay = new Map<number, string>();
      for (const rawDate of dates) {
        const row = asObject(rawDate);
        byDay.set(Number(row.xqid), text(row.mxrq));
      }
      for (const rawCourse of courses) {
        const row = asObject(rawCourse);
        const date = byDay.get(Number(row.weekDay));
        const sections = text(row.weekNoteDetail)
          .split(',')
          .map((item) => Number(item.slice(-2)))
          .filter((item) => item >= 1 && item <= 10)
          .sort((a, b) => a - b);
        if (!date || !sections.length) continue;
        target[date] ??= [];
        const baseName = text(row.courseName);
        const experimentName = text(row.syxmName);
        const first = sections[0] ?? 1;
        const last = sections.at(-1) ?? first;
        const input = {
          name: experimentName ? `${baseName} 实验：${experimentName}` : `${baseName} 实验`,
          teacherName: text(row.teacherName),
          weekDuration: `第${text(row.kkzc)}周`,
          location: text(row.classroomName),
          startSection: first,
          duration: last - first + 1,
          isExperiment: true,
        };
        target[date].push({ id: stableCourseId(semesterId, date, input), ...input });
      }
    }
  }
  async scores(token: string, semesterId: string): Promise<ScoresResultDto> {
    const payload = await this.post(
      `/njwhd/student/termGPA?semester=${encodeURIComponent(semesterId)}&type=1`,
      { token, auth: 'token' },
    );
    const groups = asArray(payload.data ?? []);
    if (groups.length === 0) {
      return {
        scores: [],
        summary: { earnedCredits: '', totalGradePoints: '', averageGradePoint: '' },
      };
    }
    const group = asObject(groups[0]);
    const scores = asArray(group.achievement ?? []).map((item) => {
      const row = asObject(item);
      return {
        courseName: text(row.courseName),
        courseAttribute: text(row.curriculumAttributes),
        courseNature: text(row.courseNature),
        examName: text(row.examName),
        examNature: text(row.examinationNature),
        score: text(row.fraction),
        passed: text(row.sfjg) === '是' || text(row.sfjg) === '1',
        gradePoint: numberValue(row.jd),
        credit: numberValue(row.credit),
      };
    });
    return {
      scores,
      summary: {
        earnedCredits: text(group.yxzxf),
        totalGradePoints: text(group.zxfjd),
        averageGradePoint: text(group.pjxfjd),
      },
    };
  }
  async exams(token: string): Promise<ExamDto[]> {
    const payload = await this.post('/njwhd/student/examinationArrangement', {
      token,
      auth: 'token',
    });
    return asArray(payload.data ?? []).map((item) => {
      const row = asObject(item);
      return {
        courseName: text(row.courseName || row.kcmc),
        date: text(row.examDate || row.ksrq),
        time: text(row.examTime || row.kssj),
        location: text(row.location || row.ksdd),
        seat: text(row.seat || row.zwh),
      };
    });
  }
  async buildings(token: string): Promise<BuildingDto[]> {
    const termPayload = await this.post('/njwhd/currentTerm', { token, auth: 'token' });
    const terms = asArray(termPayload.data ?? []);
    if (terms.length === 0) return [];
    const term = asObject(terms[0]);
    const semesterId = text(term.semesterId);
    const query = new URLSearchParams({
      campusId: '',
      jiaoxueloumc: '',
      zhouci: '40',
      xnxq: semesterId,
      searchType: 'lylv',
    });
    const payload = await this.post(`/njwhd/student/getIdleClassroom?${query.toString()}`, {
      token,
      auth: 'token',
    });
    return asArray(payload.data ?? []).map((item) => {
      const row = asObject(item);
      return { id: text(row.buildingId), name: text(row.teachingBuildingName) };
    });
  }
  async freeRooms(
    token: string,
    input: { date: string; nodeId: string; buildingId: string },
  ): Promise<FreeRoomDto[]> {
    const termPayload = await this.post('/njwhd/currentTerm', { token, auth: 'token' });
    const terms = asArray(termPayload.data ?? []);
    if (terms.length === 0) return [];
    const term = asObject(terms[0]);
    const query = new URLSearchParams({
      ...input,
      campusId: '',
      jsmc: '',
      xnxq: text(term.semesterId),
      jiaoxueloumc: '',
    });
    const payload = await this.post(`/njwhd/student/getIdleClassroom?${query.toString()}`, {
      token,
      auth: 'token',
    });
    return asArray(payload.data ?? []).map((item, index) => {
      const row = asObject(item);
      return {
        id: text(row.classroomId) || `${input.buildingId}-${index}`,
        name: text(row.classroomname),
        seatNumber: text(row.seatnumber),
        occupied: occupiedFromZyJc(row.zyjc),
      };
    });
  }
  async evaluationBatches(token: string): Promise<EvaluationBatchDto[]> {
    const payload = await this.post('/njwhd/student/studentEvaluate', {
      token,
      auth: 'token',
      body: {},
    });
    return asArray(payload.data ?? []).map((item) => {
      const row = asObject(item);
      return {
        id: text(row.BATCHID),
        name: text(row.EVALUATIONBATCH),
        category: text(row.KCLBMC),
        semesterName: text(row.XQMC),
        pj01id: text(row.PJ01ID),
        pj05id: text(row.PJ05ID),
      };
    });
  }
  async evaluationList(
    token: string,
    batch: { pj01id: string; batchId: string; pj05id: string },
  ): Promise<EvaluationItemDto[]> {
    const query = new URLSearchParams({
      pj01id: batch.pj01id,
      batchId: batch.batchId,
      pj05id: batch.pj05id,
      issubmit: 'all',
    });
    const payload = await this.post(`/njwhd/student/teachingEvaluation?${query.toString()}`, {
      token,
      auth: 'token',
      body: {},
    });
    return asArray(payload.data ?? []).map((item) => {
      const row = asObject(item);
      return {
        courseId: text(row.courseId),
        courseName: text(row.courseName),
        courseNumber: text(row.courseNumber),
        teacherName: text(row.teacherName),
        evaluationCategoriesId: text(row.evaluationCategoriesId),
        teacherId: text(row.teacherId),
        noticeId: text(row.noticeId),
        submitted: text(row.isSubmitCode) === '1',
      };
    });
  }
  async evaluationQuestions(
    token: string,
    item: {
      batchId: string;
      evaluationCategoriesId: string;
      courseId: string;
      teacherId: string;
      noticeId: string;
    },
  ): Promise<EvaluationQuestionDto[]> {
    const query = new URLSearchParams({
      batchId: item.batchId,
      evaluationCategoriesId: item.evaluationCategoriesId,
      courseId: item.courseId,
      teacherId: item.teacherId,
      noticeId: item.noticeId,
      schoolClassificationId: '',
    });
    const payload = await this.post(`/njwhd/student/evaluationIndex?${query.toString()}`, {
      token,
      auth: 'token',
      body: {},
    });
    const data = asObject(payload.data ?? {});
    const questions: EvaluationQuestionDto[] = [];
    for (const raw of asArray(data.targetData ?? [])) {
      const row = asObject(raw);
      if (text(row.parentTargetId) === '') continue;
      const options = asArray(row.optionData ?? []).map((rawOption) => {
        const option = asObject(rawOption);
        return {
          id: text(option.optionId),
          name: text(option.optionName),
          score: numberValue(option.optionScoreValue) ?? 0,
        };
      });
      if (options.length === 0) continue;
      questions.push({ id: text(row.targetId), name: text(row.targetName), options });
    }
    return questions;
  }
  async submitEvaluation(token: string, submission: EvaluationSubmissionDto): Promise<void> {
    const payload = await this.post('/njwhd/student/saveEvaluate', {
      token,
      auth: 'token',
      body: {
        batchId: submission.batchId,
        courseId: submission.courseId,
        evaluationCategoriesId: submission.evaluationCategoriesId,
        teacherId: submission.teacherId,
        noticeId: submission.noticeId,
        schoolClassificationId: '',
        target: submission.target.map((target) => ({
          targetid: target.questionId,
          targetval: target.optionId,
        })),
      },
    });
    if (text(payload.code) === 'success') return;
    throw new ApiError(
      'ACADEMIC_UPSTREAM_CHANGED',
      502,
      text(payload.errorMessage) || '评教提交失败，请稍后重试',
    );
  }
}
