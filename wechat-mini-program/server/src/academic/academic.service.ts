import { Inject, Injectable } from '@nestjs/common';
import type { Timetable } from '@superhut/api-contract';
import { parseStrictDate } from '@superhut/domain-rules';
import { CoordinationService } from '../coordination/coordination.service.js';
import { ApiError } from '../common/api-error.js';
import { decryptField, encryptField } from '../common/security.js';
import { environment } from '../config.js';
import { StateService } from '../state/state.service.js';
import type {
  AcademicProvider,
  EvaluationQuestionDto,
  EvaluationSubmissionDto,
  EvaluationTargetDto,
} from './academic-provider.js';
import { FixtureAcademicProvider } from './fixture-academic.provider.js';
import { RealAcademicProvider } from './real-academic.provider.js';

@Injectable()
export class AcademicService {
  private readonly fixtureRefreshLocks = new Set<string>();
  private readonly fixtureBuildingAllowlist = new Map<string, Set<string>>();
  constructor(
    @Inject(FixtureAcademicProvider) private readonly fixture: FixtureAcademicProvider,
    @Inject(RealAcademicProvider) private readonly real: RealAcademicProvider,
    @Inject(StateService) private readonly state: StateService,
    @Inject(CoordinationService) private readonly coordination: CoordinationService,
  ) {}

  private provider(): AcademicProvider {
    return environment().APP_MODE === 'fixture' ? this.fixture : this.real;
  }
  async login(studentId: string, password: string) {
    const provider = this.provider();
    const account = await provider.login(studentId, password);
    if (!(await provider.validateToken(account.token)))
      throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '教务登录状态无法验证');
    return account;
  }
  decryptStudentId(ciphertext: string): string {
    return decryptField(ciphertext);
  }
  maskName(name: string): string {
    return name.length <= 1 ? '*' : `${name.slice(0, 1)}${'*'.repeat(name.length - 1)}`;
  }
  private async tokenFor(userId: string): Promise<string> {
    const binding = (await this.state.findById(userId))?.binding;
    if (!binding || binding.status === 'unbound')
      throw new ApiError('AUTH_ACADEMIC_NOT_BOUND', 403, '请先登录教务系统');
    if (binding.status === 'expired')
      throw new ApiError('AUTH_ACADEMIC_EXPIRED', 401, '教务登录状态已失效，请重新登录');
    return decryptField(binding.tokenCiphertext);
  }
  private async guardUnavailable<T>(
    userId: string,
    token: string,
    fn: () => Promise<T>,
  ): Promise<T> {
    try {
      return await fn();
    } catch (error) {
      if (error instanceof ApiError && error.code === 'ACADEMIC_UPSTREAM_UNAVAILABLE') {
        let expired = false;
        try {
          expired = !(await this.provider().validateToken(token));
        } catch {
          // validateToken 也失败（学校整体故障），保持原 unavailable，不误判为过期
          expired = false;
        }
        if (expired) {
          await this.state.markBindingExpired(userId);
          throw new ApiError('AUTH_ACADEMIC_EXPIRED', 401, '教务登录状态已失效，请重新登录');
        }
      }
      throw error;
    }
  }
  private async withToken<T>(userId: string, fn: (token: string) => Promise<T>): Promise<T> {
    const token = await this.tokenFor(userId);
    return this.guardUnavailable(userId, token, () => fn(token));
  }
  async semesters(userId: string) {
    return this.withToken(userId, (token) => this.provider().semesters(token));
  }
  async timetable(
    userId: string,
  ): Promise<{ value: Timetable; fetchedAt: string; stale: boolean }> {
    const fixture = this.state.fixtureSnapshot<Timetable>(userId, 'timetable', '');
    if (fixture)
      return {
        value: fixture.value,
        fetchedAt: fixture.fetchedAt,
        stale: Date.now() > Date.parse(fixture.expiresAt),
      };
    const snapshot = await this.state.getSnapshot(userId, 'timetable', '');
    if (!snapshot) throw new ApiError('AUTH_ACADEMIC_NOT_BOUND', 403, '暂无课表，请先刷新');
    return {
      value: JSON.parse(decryptField(snapshot.payloadCiphertext)) as Timetable,
      fetchedAt: snapshot.fetchedAt,
      stale: Date.now() > Date.parse(snapshot.expiresAt),
    };
  }
  async refreshTimetable(
    userId: string,
    semesterId = '',
  ): Promise<{ value: Timetable; fetchedAt: string }> {
    let owner: string | undefined;
    if (environment().APP_MODE === 'fixture') {
      if (this.fixtureRefreshLocks.has(userId))
        throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '课表正在刷新，请稍候');
      this.fixtureRefreshLocks.add(userId);
    } else {
      owner = await this.coordination.acquireLock(`timetable-refresh:${userId}`);
      if (!owner) throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '课表正在刷新，请稍候');
    }
    try {
      const value = await this.withToken(userId, (token) =>
        this.provider().refreshTimetable(token, semesterId),
      );
      const snapshot = await this.state.saveSnapshot(
        userId,
        'timetable',
        '',
        encryptField(JSON.stringify(value)),
        value,
        24 * 60 * 60 * 1000,
      );
      return { value, fetchedAt: snapshot.fetchedAt };
    } finally {
      this.fixtureRefreshLocks.delete(userId);
      if (owner) await this.coordination.releaseLock(`timetable-refresh:${userId}`, owner);
    }
  }
  async scores(userId: string, semesterId: string) {
    const value = await this.withToken(userId, (token) =>
      this.provider().scores(token, semesterId),
    );
    await this.state.saveSnapshot(
      userId,
      'scores',
      semesterId,
      encryptField(JSON.stringify(value)),
      value,
      6 * 60 * 60 * 1000,
    );
    return value;
  }
  async exams(userId: string) {
    const value = await this.withToken(userId, (token) => this.provider().exams(token));
    await this.state.saveSnapshot(
      userId,
      'exams',
      '',
      encryptField(JSON.stringify(value)),
      value,
      6 * 60 * 60 * 1000,
    );
    return value;
  }
  async buildings(userId: string) {
    const cached = await this.coordination.getJson<Array<{ id: string; name: string }>>(
      `buildings:${userId}`,
    );
    const buildings =
      cached ?? (await this.withToken(userId, (token) => this.provider().buildings(token)));
    if (!cached) await this.coordination.setJson(`buildings:${userId}`, buildings, 3600);
    this.fixtureBuildingAllowlist.set(userId, new Set(buildings.map(({ id }) => id)));
    await this.coordination.setJson(
      `building-allowlist:${userId}`,
      buildings.map(({ id }) => id),
      3600,
    );
    return buildings;
  }
  async freeRooms(userId: string, input: { date: string; nodeId: string; buildingId: string }) {
    if (!parseStrictDate(input.date) || !isValidNodeId(input.nodeId))
      throw new ApiError('VALIDATION_ERROR', 400, '日期或节次不正确');
    const cachedAllowlist = await this.coordination.getJson<string[]>(
      `building-allowlist:${userId}`,
    );
    const allowed =
      cachedAllowlist?.includes(input.buildingId) ??
      this.fixtureBuildingAllowlist.get(userId)?.has(input.buildingId) ??
      false;
    if (!allowed) throw new ApiError('VALIDATION_ERROR', 400, '请重新选择教学楼');
    const key = `free-rooms:${userId}:${input.date}:${input.nodeId}:${input.buildingId}`;
    const cached = await this.coordination.getJson<Array<{ id: string; name: string }>>(key);
    if (cached) return cached;
    const value = await this.withToken(userId, (token) => this.provider().freeRooms(token, input));
    await this.coordination.setJson(key, value, 300);
    return value;
  }
  async evaluationBatches(userId: string) {
    return this.withToken(userId, (token) => this.provider().evaluationBatches(token));
  }
  async evaluationList(userId: string, batch: { pj01id: string; batchId: string; pj05id: string }) {
    if (!batch.batchId) throw new ApiError('VALIDATION_ERROR', 400, '请选择评教批次');
    return this.withToken(userId, (token) => this.provider().evaluationList(token, batch));
  }
  async evaluationQuestions(
    userId: string,
    item: {
      batchId: string;
      evaluationCategoriesId: string;
      courseId: string;
      teacherId: string;
      noticeId: string;
    },
  ) {
    if (!item.courseId) throw new ApiError('VALIDATION_ERROR', 400, '请选择要评教的课程');
    return this.withToken(userId, (token) => this.provider().evaluationQuestions(token, item));
  }
  async submitEvaluation(userId: string, submission: EvaluationSubmissionDto) {
    if (submission.target.length === 0)
      throw new ApiError('VALIDATION_ERROR', 400, '请完成所有题目后再提交');
    await this.withToken(userId, (token) => this.provider().submitEvaluation(token, submission));
    return { submitted: true };
  }
  async autoSubmitOne(
    userId: string,
    item: {
      batchId: string;
      evaluationCategoriesId: string;
      courseId: string;
      teacherId: string;
      noticeId: string;
    },
  ) {
    return this.withToken(userId, async (token) => {
      const questions = await this.provider().evaluationQuestions(token, item);
      if (questions.length === 0)
        throw new ApiError('ACADEMIC_UPSTREAM_CHANGED', 502, '未获取到评教题目');
      await this.provider().submitEvaluation(token, {
        batchId: item.batchId,
        courseId: item.courseId,
        evaluationCategoriesId: item.evaluationCategoriesId,
        teacherId: item.teacherId,
        noticeId: item.noticeId,
        target: buildAutoEvaluationTargets(questions),
      });
      return { submitted: true };
    });
  }
  async autoSubmitAll(userId: string, batch: { pj01id: string; batchId: string; pj05id: string }) {
    const token = await this.tokenFor(userId);
    const items = await this.guardUnavailable(userId, token, () =>
      this.provider().evaluationList(token, batch),
    );
    const pending = items.filter((item) => !item.submitted);
    const results: Array<{
      courseId: string;
      courseName: string;
      success: boolean;
      message?: string;
    }> = [];
    for (const item of pending) {
      try {
        const questions = await this.provider().evaluationQuestions(token, {
          batchId: batch.batchId,
          evaluationCategoriesId: item.evaluationCategoriesId,
          courseId: item.courseId,
          teacherId: item.teacherId,
          noticeId: item.noticeId,
        });
        await this.provider().submitEvaluation(token, {
          batchId: batch.batchId,
          courseId: item.courseId,
          evaluationCategoriesId: item.evaluationCategoriesId,
          teacherId: item.teacherId,
          noticeId: item.noticeId,
          target: buildAutoEvaluationTargets(questions),
        });
        results.push({ courseId: item.courseId, courseName: item.courseName, success: true });
      } catch (error) {
        results.push({
          courseId: item.courseId,
          courseName: item.courseName,
          success: false,
          message: error instanceof Error ? error.message : '评教失败',
        });
      }
    }
    return {
      total: pending.length,
      succeeded: results.filter((result) => result.success).length,
      failed: results.filter((result) => !result.success).length,
      results,
    };
  }
}

/**
 * 自动评教：复刻 Flutter 版策略——第 1 题选低于 4.75 分的选项、其余题选不低于 4.75 分的
 * 选项（最高分好评）。若某题没有符合条件的选项，则退而选该题分数最低（第 1 题）或最高
 * （其余题）的选项，避免漏题导致提交失败。
 */
export function buildAutoEvaluationTargets(
  questions: EvaluationQuestionDto[],
): EvaluationTargetDto[] {
  return questions
    .map((question, index) => {
      const options = question.options;
      if (options.length === 0) return null;
      let selected =
        index === 0
          ? options.find((option) => option.score < 4.75)
          : options.find((option) => option.score >= 4.75);
      if (!selected) {
        selected = [...options].sort((a, b) =>
          index === 0 ? a.score - b.score : b.score - a.score,
        )[0];
      }
      return selected ? { questionId: question.id, optionId: selected.id } : null;
    })
    .filter((target): target is EvaluationTargetDto => target !== null);
}

/**
 * 空教室 nodeId：起止节次各补零到两位拼接，如 0102、0112；起始/结束节 ∈ [1,12] 且起始 ≤ 结束。
 */
export function isValidNodeId(nodeId: string): boolean {
  if (!/^\d{4}$/.test(nodeId)) return false;
  const start = Number(nodeId.slice(0, 2));
  const end = Number(nodeId.slice(2, 4));
  return start >= 1 && start <= 12 && end >= 1 && end <= 12 && start <= end;
}
