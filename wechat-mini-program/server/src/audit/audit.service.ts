import { Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { hmacIndex } from '../common/security.js';
import { environment } from '../config.js';
import { DatabaseService } from '../database/database.service.js';
import { auditEvents } from '../database/schema.js';

@Injectable()
export class AuditService {
  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  async record(input: {
    userId?: string;
    eventType: string;
    result: 'success' | 'failure';
    requestId: string;
    upstreamStatusClass?: string;
  }): Promise<void> {
    if (environment().APP_MODE === 'fixture') return;
    try {
      await this.database
        .db()
        .insert(auditEvents)
        .values({
          id: randomUUID(),
          anonymousUserId: input.userId ? hmacIndex(input.userId) : null,
          eventType: input.eventType,
          result: input.result,
          requestId: input.requestId,
          upstreamStatusClass: input.upstreamStatusClass,
          createdAt: new Date(),
        });
    } catch {
      // Audit failures must not turn an already-completed state change into a retryable client error.
    }
  }
}
