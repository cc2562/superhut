import { Module } from '@nestjs/common';
import { AcademicController } from './academic/academic.controller.js';
import { AcademicService } from './academic/academic.service.js';
import { FixtureAcademicProvider } from './academic/fixture-academic.provider.js';
import { RealAcademicProvider } from './academic/real-academic.provider.js';
import { AuthController } from './auth/auth.controller.js';
import { AuthService } from './auth/auth.service.js';
import { MeController } from './auth/me.controller.js';
import { SessionService } from './auth/session.service.js';
import { WechatIdentityService } from './auth/wechat-identity.service.js';
import { LoginThrottleService } from './auth/login-throttle.service.js';
import { HealthController } from './health.controller.js';
import { OpenApiController } from './openapi.controller.js';
import { StateService } from './state/state.service.js';
import { DatabaseService } from './database/database.service.js';
import { CoordinationService } from './coordination/coordination.service.js';
import { AuditService } from './audit/audit.service.js';

@Module({
  controllers: [
    HealthController,
    OpenApiController,
    AuthController,
    MeController,
    AcademicController,
  ],
  providers: [
    DatabaseService,
    CoordinationService,
    AuditService,
    StateService,
    SessionService,
    LoginThrottleService,
    WechatIdentityService,
    FixtureAcademicProvider,
    RealAcademicProvider,
    AcademicService,
    AuthService,
  ],
})
export class AppModule {}
