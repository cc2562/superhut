import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { IncomingHttpHeaders } from 'node:http';
import {
  type AcademicLoginRequest,
  AcademicLoginRequestSchema,
  type AcademicLoginResponse,
  AcademicReloginRequestSchema,
  type Timetable,
  WechatLoginRequestSchema,
} from '@superhut/api-contract';
import { AcademicService } from '../academic/academic.service.js';
import { CoordinationService } from '../coordination/coordination.service.js';
import { ApiError } from '../common/api-error.js';
import { encryptField, hmacIndex, maskStudentId } from '../common/security.js';
import { StateService } from '../state/state.service.js';
import { LoginThrottleService } from './login-throttle.service.js';
import { SessionService } from './session.service.js';
import { WechatIdentityService } from './wechat-identity.service.js';

@Injectable()
export class AuthService {
  constructor(
    @Inject(WechatIdentityService) private readonly identities: WechatIdentityService,
    @Inject(SessionService) private readonly sessions: SessionService,
    @Inject(StateService) private readonly state: StateService,
    @Inject(AcademicService) private readonly academic: AcademicService,
    @Inject(LoginThrottleService) private readonly throttle: LoginThrottleService,
    @Inject(CoordinationService) private readonly coordination: CoordinationService,
  ) {}

  async loginWechat(input: unknown, headers: IncomingHttpHeaders) {
    const request = WechatLoginRequestSchema.parse(input);
    const identity = this.identities.fromTrustedHeaders(headers);
    const openidHash = hmacIndex(identity.openid);
    const user = await this.state.getOrCreate(
      openidHash,
      () => ({ id: randomUUID(), openidCiphertext: encryptField(identity.openid) }),
      request.privacyConsentVersion,
      identity.unionid ? encryptField(identity.unionid) : undefined,
    );
    return {
      ...(await this.sessions.create(user.id)),
      academicBinding: await this.bindingView(user.id),
    };
  }

  async loginAcademic(userId: string, input: unknown, ip: string): Promise<AcademicLoginResponse> {
    const request: AcademicLoginRequest = AcademicLoginRequestSchema.parse(input);
    const academicBinding = await this.performLogin(
      userId,
      request.studentId,
      request.password,
      ip,
    );
    // 登录成功后顺带完成首次课表刷新并返回，避免前端登录后再次触发「刷新课表」验证码。
    let timetable: Timetable | null = null;
    let timetableFetchedAt: string | null = null;
    try {
      const snapshot = await this.academic.refreshTimetable(userId);
      timetable = snapshot.value;
      timetableFetchedAt = snapshot.fetchedAt;
    } catch {
      // 降级：课表刷新失败不影响登录结果，前端进入课表页后展示空态/引导刷新。
    }
    return { academicBinding, timetable, timetableFetchedAt };
  }

  async reloginAcademic(userId: string, input: unknown, ip: string) {
    const request = AcademicReloginRequestSchema.parse(input);
    // 静默自动重登豁免验证码，但其安全边界是「请求学号必须与已绑定学号一致」，
    // 否则攻击者可借 relogin 撞库新学号。不一致时按凭据错误处理，不泄露是否存在该账号。
    const user = await this.requireUser(userId);
    const binding = user.binding;
    const sameStudent =
      binding &&
      binding.status !== 'unbound' &&
      hmacIndex(request.studentId) === binding.studentIdHash;
    if (!sameStudent)
      throw new ApiError(
        'AUTH_ACADEMIC_INVALID_CREDENTIALS',
        401,
        '账号、密码或学校服务状态异常，请检查后重试',
      );
    return this.performLogin(userId, request.studentId, request.password, ip);
  }

  private async performLogin(userId: string, studentId: string, password: string, ip: string) {
    const release = await this.throttle.begin(userId, studentId, ip);
    try {
      const account = await this.academic.login(studentId, password);
      await this.requireUser(userId);
      await this.state.saveBinding(userId, {
        studentIdCiphertext: encryptField(studentId),
        studentIdHash: hmacIndex(studentId),
        tokenCiphertext: encryptField(account.token),
        displayName: account.displayName,
        status: 'active',
      });
      return this.bindingView(userId);
    } finally {
      await release();
    }
  }

  async bindingView(userId: string): Promise<{
    status: 'active' | 'expired' | 'unbound';
    studentIdMasked?: string;
    displayName?: string;
  }> {
    const user = await this.requireUser(userId);
    if (!user.binding || user.binding.status === 'unbound') return { status: 'unbound' };
    const view: { status: 'active' | 'expired'; studentIdMasked?: string; displayName?: string } = {
      status: user.binding.status,
      studentIdMasked: maskStudentId(
        this.academic.decryptStudentId(user.binding.studentIdCiphertext),
      ),
    };
    if (user.binding.displayName)
      view.displayName = this.academic.maskName(user.binding.displayName);
    return view;
  }

  async unbind(userId: string): Promise<void> {
    await this.requireUser(userId);
    await this.state.deleteBinding(userId);
    await this.coordination.deleteByPrefix(`buildings:${userId}`);
    await this.coordination.deleteByPrefix(`building-allowlist:${userId}`);
    await this.coordination.deleteByPrefix(`free-rooms:${userId}:`);
  }

  async deleteUser(userId: string): Promise<void> {
    await this.sessions.revokeUser(userId);
    await this.state.deleteUser(userId);
    await this.coordination.deleteByPrefix(`buildings:${userId}`);
    await this.coordination.deleteByPrefix(`building-allowlist:${userId}`);
    await this.coordination.deleteByPrefix(`free-rooms:${userId}:`);
  }

  async requireUser(userId: string) {
    const user = await this.state.findById(userId);
    if (!user) throw new ApiError('AUTH_REQUIRED', 401, '请重新登录');
    return user;
  }
}
