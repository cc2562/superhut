import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, type NestFastifyApplication } from '@nestjs/platform-fastify';
import helmet from '@fastify/helmet';
import { AppModule } from './app.module.js';
import { ApiExceptionFilter } from './common/api-exception.filter.js';
import { environment } from './config.js';

export async function bootstrap(): Promise<NestFastifyApplication> {
  const env = environment();
  const adapter = new FastifyAdapter({
    logger: {
      level: env.NODE_ENV === 'test' ? 'silent' : 'info',
      redact: {
        paths: [
          'req.headers.authorization',
          'req.body.password',
          'req.body.refreshToken',
          'res.headers.set-cookie',
        ],
        censor: '[Redacted]',
      },
    },
    requestIdHeader: 'x-request-id',
  });
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, adapter, {
    bufferLogs: true,
  });
  await app.register(helmet, { contentSecurityPolicy: false });
  app.useGlobalFilters(new ApiExceptionFilter());
  app.enableShutdownHooks();
  return app;
}

if (process.env.NODE_ENV !== 'test') {
  const app = await bootstrap();
  await app.listen({ port: environment().PORT, host: '0.0.0.0' });
}
