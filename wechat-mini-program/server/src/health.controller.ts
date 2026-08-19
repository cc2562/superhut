import { Controller, Get, Inject, Req, Res } from '@nestjs/common';
import { successResponse } from '@superhut/api-contract';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { requestId } from './common/request-context.js';
import { DatabaseService } from './database/database.service.js';

@Controller('health')
export class HealthController {
  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  @Get('live') live(@Req() request: FastifyRequest) {
    return successResponse({ status: 'ok' }, requestId(request));
  }

  @Get('ready') async ready(
    @Req() request: FastifyRequest,
    @Res({ passthrough: true }) reply: FastifyReply,
  ) {
    const ready = await this.database.ready();
    if (!ready) reply.status(503);
    return successResponse({ status: ready ? 'ready' : 'unavailable' }, requestId(request));
  }
}
