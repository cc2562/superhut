import { Inject, Injectable } from '@nestjs/common';
import { CoordinationService } from '../coordination/coordination.service.js';
import { ApiError } from '../common/api-error.js';
import { hmacIndex } from '../common/security.js';
import { environment } from '../config.js';

interface Counter {
  attempts: number;
  resetsAt: number;
}

@Injectable()
export class LoginThrottleService {
  private readonly fixtureCounters = new Map<string, Counter>();
  private readonly fixtureActiveUsers = new Set<string>();
  constructor(@Inject(CoordinationService) private readonly coordination: CoordinationService) {}

  async begin(userId: string, studentId: string, ip: string): Promise<() => Promise<void>> {
    const studentHash = hmacIndex(studentId);
    if (environment().APP_MODE === 'fixture') {
      if (this.fixtureActiveUsers.has(userId))
        throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '登录正在处理中，请稍候');
      this.consumeFixture(`ip:${ip}`, 20);
      this.consumeFixture(`user:${userId}`, 5);
      this.consumeFixture(`student:${studentHash}`, 5);
      this.fixtureActiveUsers.add(userId);
      return async () => {
        this.fixtureActiveUsers.delete(userId);
      };
    }
    const permitted = await Promise.all([
      this.coordination.consume(`academic-login:ip:${hmacIndex(ip)}`, 20, 5 * 60_000),
      this.coordination.consume(`academic-login:user:${userId}`, 5, 5 * 60_000),
      this.coordination.consume(`academic-login:student:${studentHash}`, 5, 5 * 60_000),
    ]);
    if (permitted.some((value) => !value))
      throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '尝试次数较多，请稍后重试');
    const owner = await this.coordination.acquireLock(`academic-login:${userId}`);
    if (!owner) throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '登录正在处理中，请稍候');
    return () => this.coordination.releaseLock(`academic-login:${userId}`, owner);
  }

  private consumeFixture(key: string, limit: number): void {
    const now = Date.now();
    const current = this.fixtureCounters.get(key);
    const counter =
      !current || current.resetsAt <= now ? { attempts: 0, resetsAt: now + 5 * 60_000 } : current;
    if (counter.attempts >= limit)
      throw new ApiError('ACADEMIC_RATE_LIMITED', 429, '尝试次数较多，请稍后重试');
    counter.attempts += 1;
    this.fixtureCounters.set(key, counter);
  }
}
