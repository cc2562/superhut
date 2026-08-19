import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { IncomingHttpHeaders } from 'node:http';
import {
  type AcademicLoginRequest,
  AcademicLoginRequestSchema,
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

  async loginAcademic(userId: string, input: unknown, ip: string) {
    const request: AcademicLoginRequest = AcademicLoginRequestSchema.parse(input);
    const release = await this.throttle.begin(userId, request.studentId, ip);
    try {
      const account = await this.academic.login(request.studentId, request.password);
      await this.requireUser(userId);
      await this.state.saveBinding(userId, {
        studentIdCiphertext: encryptField(request.studentId),
        studentIdHash: hmacIndex(request.studentId),
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
