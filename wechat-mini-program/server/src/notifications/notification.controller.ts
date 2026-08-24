import { Controller, Get, Headers, Inject, Param, Post, Query, Req } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import { successResponse } from '@superhut/api-contract';
import { requestId } from '../common/request-context.js';
import { SessionService } from '../auth/session.service.js';
import { NotificationService } from './notification.service.js';

@Controller('v1/notifications')
export class NotificationController {
  constructor(
    @Inject(NotificationService) private readonly notifications: NotificationService,
    @Inject(SessionService) private readonly sessions: SessionService,
  ) {}

  @Get('summary') async summary(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(await this.notifications.summary(userId), requestId(request));
  }

  @Get() async list(
    @Headers('authorization') authorization: string | undefined,
    @Query('cursor') cursor: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(await this.notifications.list(userId, cursor), requestId(request));
  }

  @Get(':id') async detail(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(await this.notifications.detail(userId, id), requestId(request));
  }

  @Post(':id/read') async read(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    await this.notifications.markRead(userId, id);
    return successResponse({ read: true }, requestId(request));
  }
}
