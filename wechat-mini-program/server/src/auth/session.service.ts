import { Inject, Injectable } from '@nestjs/common';
import { and, eq, gt, isNull } from 'drizzle-orm';
import { createHmac, randomUUID } from 'node:crypto';
import { ApiError } from '../common/api-error.js';
import { token } from '../common/security.js';
import { environment } from '../config.js';
import { DatabaseService } from '../database/database.service.js';
import { sessions } from '../database/schema.js';

interface FixtureSession {
  id: string;
  userId: string;
  accessHash: string;
  refreshHash: string;
  accessExpiresAt: number;
  refreshExpiresAt: number;
  revoked: boolean;
}
@Injectable()
export class SessionService {
  private readonly fixtureSessions = new Map<string, FixtureSession>();
  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  private hash(value: string): string {
    return createHmac('sha256', environment().SESSION_SIGNING_KEY).update(value).digest('hex');
  }

  async create(userId: string): Promise<{
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
  }> {
    const accessToken = token();
    const refreshToken = token(48);
    const accessHash = this.hash(accessToken);
    const refreshHash = this.hash(refreshToken);
    const now = Date.now();
    const expiresIn = 900;
    const state = {
      id: randomUUID(),
      userId,
      accessHash,
      refreshHash,
      accessExpiresAt: now + expiresIn * 1000,
      refreshExpiresAt: now + 30 * 24 * 60 * 60 * 1000,
      revoked: false,
    };
    if (environment().APP_MODE === 'fixture') this.fixtureSessions.set(accessHash, state);
    else {
      await this.database
        .db()
        .insert(sessions)
        .values({
          id: state.id,
          userId,
          accessTokenHash: accessHash,
          refreshTokenHash: refreshHash,
          accessExpiresAt: new Date(state.accessExpiresAt),
          refreshExpiresAt: new Date(state.refreshExpiresAt),
          createdAt: new Date(now),
        });
    }
    return { accessToken, refreshToken, expiresIn };
  }

  async resolveAuthorization(header: string | undefined): Promise<string> {
    const accessToken = header?.startsWith('Bearer ') ? header.slice(7) : '';
    const accessHash = this.hash(accessToken);
    if (environment().APP_MODE === 'fixture') {
      const session = this.fixtureSessions.get(accessHash);
      if (!session || session.revoked || session.accessExpiresAt <= Date.now())
        throw new ApiError('AUTH_REQUIRED', 401, '请重新登录');
      return session.userId;
    }
    const [session] = await this.database
      .db()
      .select({ userId: sessions.userId })
      .from(sessions)
      .where(
        and(
          eq(sessions.accessTokenHash, accessHash),
          isNull(sessions.revokedAt),
          gt(sessions.accessExpiresAt, new Date()),
        ),
      )
      .limit(1);
    if (!session) throw new ApiError('AUTH_REQUIRED', 401, '请重新登录');
    return session.userId;
  }

  async refresh(refreshToken: string): Promise<{
    userId: string;
    tokens: { accessToken: string; refreshToken: string; expiresIn: number };
  }> {
    const refreshHash = this.hash(refreshToken);
    if (environment().APP_MODE === 'fixture') {
      const session = [...this.fixtureSessions.values()].find(
        (candidate) => candidate.refreshHash === refreshHash && !candidate.revoked,
      );
      if (!session || session.refreshExpiresAt <= Date.now())
        throw new ApiError('AUTH_REQUIRED', 401, '登录状态已失效');
      session.revoked = true;
      return { userId: session.userId, tokens: await this.create(session.userId) };
    }
    const userId = await this.database.db().transaction(async (tx) => {
      const [session] = await tx
        .select()
        .from(sessions)
        .where(eq(sessions.refreshTokenHash, refreshHash))
        .for('update')
        .limit(1);
      if (!session || session.revokedAt || session.refreshExpiresAt <= new Date())
        throw new ApiError('AUTH_REQUIRED', 401, '登录状态已失效');
      await tx.update(sessions).set({ revokedAt: new Date() }).where(eq(sessions.id, session.id));
      return session.userId;
    });
    return { userId, tokens: await this.create(userId) };
  }

  async revokeAccess(header: string | undefined): Promise<void> {
    const accessToken = header?.startsWith('Bearer ') ? header.slice(7) : '';
    const accessHash = this.hash(accessToken);
    if (environment().APP_MODE === 'fixture') {
      const session = this.fixtureSessions.get(accessHash);
      if (session) session.revoked = true;
      return;
    }
    await this.database
      .db()
      .update(sessions)
      .set({ revokedAt: new Date() })
      .where(eq(sessions.accessTokenHash, accessHash));
  }

  async revokeUser(userId: string): Promise<void> {
    if (environment().APP_MODE === 'fixture') {
      for (const session of this.fixtureSessions.values())
        if (session.userId === userId) session.revoked = true;
      return;
    }
    await this.database
      .db()
      .update(sessions)
      .set({ revokedAt: new Date() })
      .where(and(eq(sessions.userId, userId), isNull(sessions.revokedAt)));
  }
}
