import { Inject, Injectable } from '@nestjs/common';
import { eq, like } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import { hmacIndex } from '../common/security.js';
import { environment } from '../config.js';
import { DatabaseService } from '../database/database.service.js';
import { rateLimits, runtimeCache } from '../database/schema.js';

interface FixtureCounter {
  attempts: number;
  resetsAt: number;
}

@Injectable()
export class CoordinationService {
  private readonly fixtureCounters = new Map<string, FixtureCounter>();
  private readonly fixtureLocks = new Set<string>();
  private readonly fixtureCache = new Map<string, { payload: string; expiresAt: number }>();

  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  async consume(key: string, limit: number, windowMs: number): Promise<boolean> {
    if (environment().APP_MODE === 'fixture') {
      const now = Date.now();
      const current = this.fixtureCounters.get(key);
      const counter =
        !current || current.resetsAt <= now ? { attempts: 0, resetsAt: now + windowMs } : current;
      counter.attempts += 1;
      this.fixtureCounters.set(key, counter);
      return counter.attempts <= limit;
    }
    return this.database.db().transaction(async (tx) => {
      const now = new Date();
      const [row] = await tx.select().from(rateLimits).where(eq(rateLimits.key, key)).for('update');
      if (!row || row.resetsAt <= now) {
        await tx
          .insert(rateLimits)
          .values({
            key,
            attempts: 1,
            resetsAt: new Date(now.getTime() + windowMs),
            updatedAt: now,
          })
          .onDuplicateKeyUpdate({
            set: { attempts: 1, resetsAt: new Date(now.getTime() + windowMs), updatedAt: now },
          });
        return true;
      }
      if (row.attempts >= limit) return false;
      await tx
        .update(rateLimits)
        .set({ attempts: row.attempts + 1, updatedAt: now })
        .where(eq(rateLimits.key, key));
      return true;
    });
  }

  async acquireLock(key: string): Promise<string | undefined> {
    if (environment().APP_MODE === 'fixture') {
      if (this.fixtureLocks.has(key)) return undefined;
      this.fixtureLocks.add(key);
      return key;
    }
    const owner = randomUUID();
    const release = await this.database.acquireAdvisoryLock(
      `superhut_${hmacIndex(key).slice(0, 48)}`,
      0,
    );
    if (!release) return undefined;
    this.database.registerLock(owner, release);
    return owner;
  }

  async releaseLock(key: string, owner: string): Promise<void> {
    if (environment().APP_MODE === 'fixture') {
      this.fixtureLocks.delete(key);
      return;
    }
    await this.database.releaseRegisteredLock(owner);
  }

  async getJson<T>(key: string): Promise<T | undefined> {
    if (environment().APP_MODE === 'fixture') {
      const item = this.fixtureCache.get(key);
      if (!item || item.expiresAt <= Date.now()) {
        this.fixtureCache.delete(key);
        return undefined;
      }
      return JSON.parse(item.payload) as T;
    }
    const [row] = await this.database
      .db()
      .select()
      .from(runtimeCache)
      .where(eq(runtimeCache.key, key))
      .limit(1);
    if (!row) return undefined;
    if (row.expiresAt <= new Date()) {
      await this.database.db().delete(runtimeCache).where(eq(runtimeCache.key, key));
      return undefined;
    }
    return JSON.parse(row.payload) as T;
  }

  async setJson(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    const payload = JSON.stringify(value);
    if (environment().APP_MODE === 'fixture') {
      this.fixtureCache.set(key, { payload, expiresAt: Date.now() + ttlSeconds * 1000 });
      return;
    }
    const now = new Date();
    await this.database
      .db()
      .insert(runtimeCache)
      .values({
        key,
        payload,
        expiresAt: new Date(now.getTime() + ttlSeconds * 1000),
        updatedAt: now,
      })
      .onDuplicateKeyUpdate({
        set: { payload, expiresAt: new Date(now.getTime() + ttlSeconds * 1000), updatedAt: now },
      });
  }

  async deleteByPrefix(prefix: string): Promise<void> {
    if (environment().APP_MODE === 'fixture') {
      for (const key of this.fixtureCache.keys())
        if (key.startsWith(prefix)) this.fixtureCache.delete(key);
      return;
    }
    await this.database
      .db()
      .delete(runtimeCache)
      .where(like(runtimeCache.key, `${prefix}%`));
  }
}
