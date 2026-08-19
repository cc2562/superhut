import { Body, Controller, Delete, Get, Headers, Inject, Post, Req } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { successResponse } from '@superhut/api-contract';
import { requestId } from '../common/request-context.js';
import { AuditService } from '../audit/audit.service.js';
import { AuthService } from './auth.service.js';
import { SessionService } from './session.service.js';

@Controller('v1/auth')
export class AuthController {
  constructor(
    @Inject(AuthService) private readonly auth: AuthService,
    @Inject(SessionService) private readonly sessions: SessionService,
    @Inject(AuditService) private readonly audit: AuditService,
  ) {}
  @Post('wechat/login') async wechat(@Body() body: unknown, @Req() request: FastifyRequest) {
    return successResponse(await this.auth.loginWechat(body, request.headers), requestId(request));
  }
  @Post('refresh') async refresh(@Body() body: unknown, @Req() request: FastifyRequest) {
    const refreshToken =
      typeof body === 'object' &&
      body !== null &&
      'refreshToken' in body &&
      typeof body.refreshToken === 'string'
        ? body.refreshToken
        : '';
    const refreshed = await this.sessions.refresh(refreshToken);
    await this.audit.record({
      userId: refreshed.userId,
      eventType: 'session.refresh',
      result: 'success',
      requestId: requestId(request),
    });
    return successResponse(refreshed.tokens, requestId(request));
  }
  @Post('logout') async logout(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    await this.sessions.revokeAccess(authorization);
    await this.audit.record({
      userId,
      eventType: 'session.logout',
      result: 'success',
      requestId: requestId(request),
    });
    return successResponse({ loggedOut: true }, requestId(request));
  }
  @Post('academic/login') async academicLogin(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    try {
      const academicBinding = await this.auth.loginAcademic(userId, body, this.clientIp(request));
      await this.audit.record({
        userId,
        eventType: 'academic.login',
        result: 'success',
        requestId: requestId(request),
      });
      return successResponse({ academicBinding }, requestId(request));
    } catch (error) {
      await this.audit.record({
        userId,
        eventType: 'academic.login',
        result: 'failure',
        requestId: requestId(request),
      });
      throw error;
    }
  }
  @Get('academic/status') async status(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(
      { academicBinding: await this.auth.bindingView(userId) },
      requestId(request),
    );
  }
  @Delete('academic/binding') async unbind(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    await this.auth.unbind(userId);
    await this.audit.record({
      userId,
      eventType: 'academic.unbind',
      result: 'success',
      requestId: requestId(request),
    });
    return successResponse({ unbound: true }, requestId(request));
  }

  private clientIp(request: FastifyRequest): string {
    const forwarded = request.headers['x-original-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim())
      return forwarded.split(',')[0]?.trim() || request.ip;
    return request.ip;
  }
}
