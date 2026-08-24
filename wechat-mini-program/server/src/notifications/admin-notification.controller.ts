import {
  Body,
  Controller,
  Get,
  Headers,
  Inject,
  Param,
  Post,
  Query,
  Req,
  Put,
} from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import {
  AnnouncementCreateRequestSchema,
  AnnouncementPublishRequestSchema,
  AnnouncementUpdateRequestSchema,
  successResponse,
} from '@superhut/api-contract';
import { AuditService } from '../audit/audit.service.js';
import { SessionService } from '../auth/session.service.js';
import { requestId } from '../common/request-context.js';
import { NotificationService } from './notification.service.js';

@Controller('v1/admin/notifications')
export class AdminNotificationController {
  constructor(
    @Inject(NotificationService) private readonly notifications: NotificationService,
    @Inject(SessionService) private readonly sessions: SessionService,
    @Inject(AuditService) private readonly audit: AuditService,
  ) {}

  @Get('capabilities') async capabilities(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse({ canManage: this.notifications.isAdmin(userId) }, requestId(request));
  }

  @Get() async list(
    @Headers('authorization') authorization: string | undefined,
    @Query('cursor') cursor: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(await this.notifications.adminList(userId, cursor), requestId(request));
  }

  @Get(':id') async detail(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    return successResponse(await this.notifications.adminDetail(userId, id), requestId(request));
  }

  @Post() async create(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    this.notifications.requireAdmin(userId);
    const item = await this.notifications.create(
      userId,
      AnnouncementCreateRequestSchema.parse(body),
    );
    await this.record(userId, 'notification.create', item.id, request);
    return successResponse(item, requestId(request));
  }

  @Put(':id') async update(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    this.notifications.requireAdmin(userId);
    const item = await this.notifications.update(
      userId,
      id,
      AnnouncementUpdateRequestSchema.parse(body),
    );
    await this.record(userId, 'notification.update', id, request);
    return successResponse(item, requestId(request));
  }

  @Post(':id/publish') async publish(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    this.notifications.requireAdmin(userId);
    const item = await this.notifications.publish(
      userId,
      id,
      AnnouncementPublishRequestSchema.parse(body),
    );
    await this.record(userId, 'notification.publish', id, request);
    return successResponse(item, requestId(request));
  }

  @Post(':id/withdraw') async withdraw(
    @Headers('authorization') authorization: string | undefined,
    @Param('id') id: string,
    @Req() request: FastifyRequest,
  ) {
    const userId = await this.sessions.resolveAuthorization(authorization);
    this.notifications.requireAdmin(userId);
    const item = await this.notifications.withdraw(userId, id);
    await this.record(userId, 'notification.withdraw', id, request);
    return successResponse(item, requestId(request));
  }

  private async record(
    userId: string,
    eventType: string,
    announcementId: string,
    request: FastifyRequest,
  ): Promise<void> {
    await this.audit.record({
      userId,
      eventType,
      result: 'success',
      requestId: requestId(request),
      metadata: { announcementId },
    });
  }
}
