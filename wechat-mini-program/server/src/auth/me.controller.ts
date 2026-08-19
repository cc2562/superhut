import { Controller, Delete, Get, Headers, Inject, Req } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { successResponse } from '@superhut/api-contract';
import { requestId } from '../common/request-context.js';
import { AuditService } from '../audit/audit.service.js';
import { AuthService } from './auth.service.js';
import { SessionService } from './session.service.js';

@Controller('v1/me')
export class MeController {
  constructor(
    @Inject(AuthService) private readonly auth: AuthService,
    @Inject(SessionService) private readonly sessions: SessionService,
    @Inject(AuditService) private readonly audit: AuditService,
  ) {}
  @Get() async get(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(
      { id: userId, academicBinding: await this.auth.bindingView(userId) },
      requestId(request),
    );
  }
  @Delete() async remove(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    await this.auth.deleteUser(userId);
    await this.audit.record({
      userId,
      eventType: 'user.delete',
      result: 'success',
      requestId: requestId(request),
    });
    return successResponse({ deleted: true }, requestId(request));
  }
}
