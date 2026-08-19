import { Inject, Injectable } from '@nestjs/common';
import type { Timetable } from '@superhut/api-contract';
import { parseStrictDate } from '@superhut/domain-rules';
import { CoordinationService } from '../coordination/coordination.service.js';
import { ApiError } from '../common/api-error.js';
import { decryptField, encryptField } from '../common/security.js';
import { environment } from '../config.js';
import { StateService } from '../state/state.service.js';
import type { AcademicProvider } from './academic-provider.js';
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
  async semesters(userId: string) {
    return this.provider().semesters(await this.tokenFor(userId));
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
  async refreshTimetable(userId: string): Promise<{ value: Timetable; fetchedAt: string }> {
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
      const value = await this.provider().refreshTimetable(await this.tokenFor(userId));
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
    if (!semesterId) throw new ApiError('VALIDATION_ERROR', 400, '请选择学期');
    const value = await this.provider().scores(await this.tokenFor(userId), semesterId);
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
    const value = await this.provider().exams(await this.tokenFor(userId));
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
    const buildings = cached ?? (await this.provider().buildings(await this.tokenFor(userId)));
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
    if (!parseStrictDate(input.date) || !/^\d{4}$/.test(input.nodeId))
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
    const value = await this.provider().freeRooms(await this.tokenFor(userId), input);
    await this.coordination.setJson(key, value, 300);
    return value;
  }
}
