import { Body, Controller, Get, Headers, Inject, Post, Query, Req } from '@nestjs/common';
import type { FastifyRequest } from 'fastify';
import {
  EvaluationBatchRequestSchema,
  EvaluationItemRequestSchema,
  EvaluationSubmitRequestSchema,
  successResponse,
} from '@superhut/api-contract';
import { requestId } from '../common/request-context.js';
import { SessionService } from '../auth/session.service.js';
import { AcademicService } from './academic.service.js';

@Controller('v1/academic')
export class AcademicController {
  constructor(
    @Inject(AcademicService) private readonly academic: AcademicService,
    @Inject(SessionService) private readonly sessions: SessionService,
  ) {}
  private user(authorization: string | undefined): Promise<string> {
    return this.sessions.resolveAuthorization(authorization);
  }
  @Get('semesters') async semesters(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.semesters(await this.user(authorization)),
      requestId(request),
    );
  }
  @Get('timetable') async timetable(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const snapshot = await this.academic.timetable(await this.user(authorization));
    return {
      data: snapshot.value,
      meta: { requestId: requestId(request), fetchedAt: snapshot.fetchedAt, stale: snapshot.stale },
    };
  }
  @Post('timetable/refresh') async refresh(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    const snapshot = await this.academic.refreshTimetable(await this.user(authorization));
    return {
      data: snapshot.value,
      meta: { requestId: requestId(request), fetchedAt: snapshot.fetchedAt, stale: false },
    };
  }
  @Get('scores') async scores(
    @Headers('authorization') authorization: string | undefined,
    @Query('semesterId') semesterId: string,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.scores(await this.user(authorization), semesterId),
      requestId(request),
    );
  }
  @Get('exams') async exams(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.exams(await this.user(authorization)),
      requestId(request),
    );
  }
  @Get('rooms/buildings') async buildings(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.buildings(await this.user(authorization)),
      requestId(request),
    );
  }
  @Get('rooms/free') async rooms(
    @Headers('authorization') authorization: string | undefined,
    @Query('date') date: string,
    @Query('nodeId') nodeId: string,
    @Query('buildingId') buildingId: string,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.freeRooms(await this.user(authorization), { date, nodeId, buildingId }),
      requestId(request),
    );
  }
  @Get('evaluation/batches') async evaluationBatches(
    @Headers('authorization') authorization: string | undefined,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.evaluationBatches(await this.user(authorization)),
      requestId(request),
    );
  }
  @Get('evaluation/list') async evaluationList(
    @Headers('authorization') authorization: string | undefined,
    @Query('batchId') batchId: string,
    @Query('pj01id') pj01id: string,
    @Query('pj05id') pj05id: string,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.evaluationList(await this.user(authorization), {
        batchId,
        pj01id: pj01id ?? '',
        pj05id: pj05id ?? '',
      }),
      requestId(request),
    );
  }
  @Get('evaluation/questions') async evaluationQuestions(
    @Headers('authorization') authorization: string | undefined,
    @Query('batchId') batchId: string,
    @Query('evaluationCategoriesId') evaluationCategoriesId: string,
    @Query('courseId') courseId: string,
    @Query('teacherId') teacherId: string,
    @Query('noticeId') noticeId: string,
    @Req() request: FastifyRequest,
  ) {
    return successResponse(
      await this.academic.evaluationQuestions(await this.user(authorization), {
        batchId,
        evaluationCategoriesId,
        courseId,
        teacherId,
        noticeId,
      }),
      requestId(request),
    );
  }
  @Post('evaluation/submit') async evaluationSubmit(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const submission = EvaluationSubmitRequestSchema.parse(body);
    return successResponse(
      await this.academic.submitEvaluation(await this.user(authorization), submission),
      requestId(request),
    );
  }
  @Post('evaluation/auto') async evaluationAuto(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const item = EvaluationItemRequestSchema.parse(body);
    return successResponse(
      await this.academic.autoSubmitOne(await this.user(authorization), item),
      requestId(request),
    );
  }
  @Post('evaluation/auto-all') async evaluationAutoAll(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: unknown,
    @Req() request: FastifyRequest,
  ) {
    const batch = EvaluationBatchRequestSchema.parse(body);
    return successResponse(
      await this.academic.autoSubmitAll(await this.user(authorization), batch),
      requestId(request),
    );
  }
}
