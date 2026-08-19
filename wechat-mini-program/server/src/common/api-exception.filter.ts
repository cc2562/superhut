import { ArgumentsHost, Catch, type ExceptionFilter } from '@nestjs/common';
import type { FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';
import { ApiError } from './api-error.js';

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const request = http.getRequest<FastifyRequest>();
    const reply = http.getResponse<FastifyReply>();
    if (exception instanceof ApiError) {
      void reply.status(exception.status).send({
        error: { code: exception.code, message: exception.message, requestId: request.id },
      });
      return;
    }
    if (exception instanceof ZodError) {
      void reply.status(400).send({
        error: { code: 'VALIDATION_ERROR', message: '请求参数不正确', requestId: request.id },
      });
      return;
    }
    request.log.error(
      {
        err:
          exception instanceof Error
            ? { name: exception.name, message: exception.message }
            : 'unknown',
      },
      'request failed',
    );
    void reply.status(500).send({
      error: { code: 'INTERNAL_ERROR', message: '服务暂时不可用', requestId: request.id },
    });
  }
}
