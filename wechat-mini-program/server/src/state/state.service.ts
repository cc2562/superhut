import { Inject, Injectable } from '@nestjs/common';
import { and, eq } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import { environment } from '../config.js';
import { DatabaseService } from '../database/database.service.js';
import { academicBindings, academicSnapshots, privacyConsents, users } from '../database/schema.js';

export interface BindingState {
  studentIdCiphertext: string;
  studentIdHash: string;
  tokenCiphertext: string;
  displayName: string;
  status: 'active' | 'expired' | 'unbound';
}
export interface UserState {
  id: string;
  openidCiphertext: string;
  privacyConsentVersion: string;
  binding?: BindingState;
}
export interface SnapshotState<T> {
  value: T;
  fetchedAt: string;
  expiresAt: string;
}

@Injectable()
export class StateService {
  private readonly fixtureUsers = new Map<string, UserState>();
  private readonly fixtureSnapshots = new Map<string, SnapshotState<unknown>>();

  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  async getOrCreate(
    openidHash: string,
    create: () => Omit<UserState, 'privacyConsentVersion'>,
    privacyConsentVersion: string,
    unionidCiphertext?: string,
  ): Promise<UserState> {
    if (environment().APP_MODE === 'fixture') {
      const existing = this.fixtureUsers.get(openidHash);
      if (existing) {
        existing.privacyConsentVersion = privacyConsentVersion;
        return existing;
      }
      const user = { ...create(), privacyConsentVersion };
      this.fixtureUsers.set(openidHash, user);
      return user;
    }
    const db = this.database.db();
    const now = new Date();
    const candidate = create();
    await db
      .insert(users)
      .values({
        id: candidate.id,
        openidHash,
        openidCiphertext: candidate.openidCiphertext,
        unionidCiphertext,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      })
      .onDuplicateKeyUpdate({ set: { updatedAt: now, unionidCiphertext } });
    const [row] = await db.select().from(users).where(eq(users.openidHash, openidHash)).limit(1);
    if (!row) throw new Error('failed to create user');
    await db
      .insert(privacyConsents)
      .values({ userId: row.id, version: privacyConsentVersion, acceptedAt: now })
      .onDuplicateKeyUpdate({ set: { acceptedAt: now } });
    const result: UserState = {
      id: row.id,
      openidCiphertext: row.openidCiphertext,
      privacyConsentVersion,
    };
    const binding = await this.findBinding(row.id);
    if (binding) result.binding = binding;
    return result;
  }

  async findById(userId: string): Promise<UserState | undefined> {
    if (environment().APP_MODE === 'fixture') {
      return [...this.fixtureUsers.values()].find(({ id }) => id === userId);
    }
    const db = this.database.db();
    const [row] = await db
      .select()
      .from(users)
      .where(and(eq(users.id, userId), eq(users.status, 'active')))
      .limit(1);
    if (!row) return undefined;
    const result: UserState = {
      id: row.id,
      openidCiphertext: row.openidCiphertext,
      privacyConsentVersion: '',
    };
    const binding = await this.findBinding(row.id);
    if (binding) result.binding = binding;
    return result;
  }

  private async findBinding(userId: string): Promise<BindingState | undefined> {
    const [row] = await this.database
      .db()
      .select()
      .from(academicBindings)
      .where(eq(academicBindings.userId, userId))
      .limit(1);
    return row
      ? {
          studentIdCiphertext: row.studentIdCiphertext,
          studentIdHash: row.studentIdHash,
          tokenCiphertext: row.tokenCiphertext,
          displayName: row.displayName ?? '',
          status: row.status,
        }
      : undefined;
  }

  async saveBinding(userId: string, binding: BindingState): Promise<void> {
    if (environment().APP_MODE === 'fixture') {
      const user = await this.findById(userId);
      if (user) user.binding = binding;
      return;
    }
    const now = new Date();
    await this.database
      .db()
      .insert(academicBindings)
      .values({
        id: randomUUID(),
        userId,
        ...binding,
        tokenKeyVersion: environment().FIELD_ENCRYPTION_KEY_VERSION,
        createdAt: now,
        updatedAt: now,
        lastVerifiedAt: now,
      })
      .onDuplicateKeyUpdate({
        set: {
          studentIdHash: binding.studentIdHash,
          studentIdCiphertext: binding.studentIdCiphertext,
          tokenCiphertext: binding.tokenCiphertext,
          tokenKeyVersion: environment().FIELD_ENCRYPTION_KEY_VERSION,
          displayName: binding.displayName,
          status: binding.status,
          updatedAt: now,
          lastVerifiedAt: now,
        },
      });
  }

  async deleteBinding(userId: string): Promise<void> {
    if (environment().APP_MODE === 'fixture') {
      const user = await this.findById(userId);
      if (user) delete user.binding;
      for (const key of this.fixtureSnapshots.keys())
        if (key.startsWith(`${userId}:`)) this.fixtureSnapshots.delete(key);
      return;
    }
    await this.database.db().transaction(async (tx) => {
      await tx.delete(academicSnapshots).where(eq(academicSnapshots.userId, userId));
      await tx.delete(academicBindings).where(eq(academicBindings.userId, userId));
    });
  }

  async saveSnapshot<T>(
    userId: string,
    kind: 'timetable' | 'scores' | 'exams',
    semesterId: string,
    payloadCiphertext: string,
    value: T,
    ttlMs: number,
  ): Promise<SnapshotState<T>> {
    const now = new Date();
    const snapshot = {
      value,
      fetchedAt: now.toISOString(),
      expiresAt: new Date(now.getTime() + ttlMs).toISOString(),
    };
    const key = `${userId}:${kind}:${semesterId}`;
    if (environment().APP_MODE === 'fixture') {
      this.fixtureSnapshots.set(key, snapshot);
      return snapshot;
    }
    await this.database.db().transaction(async (tx) => {
      await tx
        .delete(academicSnapshots)
        .where(
          and(
            eq(academicSnapshots.userId, userId),
            eq(academicSnapshots.kind, kind),
            eq(academicSnapshots.semesterId, semesterId),
          ),
        );
      await tx.insert(academicSnapshots).values({
        id: randomUUID(),
        userId,
        kind,
        semesterId,
        payloadCiphertext,
        fetchedAt: now,
        expiresAt: new Date(snapshot.expiresAt),
      });
    });
    return snapshot;
  }

  async getSnapshot(
    userId: string,
    kind: 'timetable' | 'scores' | 'exams',
    semesterId: string,
  ): Promise<{ payloadCiphertext: string; fetchedAt: string; expiresAt: string } | undefined> {
    if (environment().APP_MODE === 'fixture') {
      const fixture = this.fixtureSnapshots.get(`${userId}:${kind}:${semesterId}`);
      return fixture
        ? { payloadCiphertext: '', fetchedAt: fixture.fetchedAt, expiresAt: fixture.expiresAt }
        : undefined;
    }
    const [row] = await this.database
      .db()
      .select()
      .from(academicSnapshots)
      .where(
        and(
          eq(academicSnapshots.userId, userId),
          eq(academicSnapshots.kind, kind),
          eq(academicSnapshots.semesterId, semesterId),
        ),
      )
      .limit(1);
    return row
      ? {
          payloadCiphertext: row.payloadCiphertext,
          fetchedAt: row.fetchedAt.toISOString(),
          expiresAt: row.expiresAt.toISOString(),
        }
      : undefined;
  }

  fixtureSnapshot<T>(
    userId: string,
    kind: string,
    semesterId: string,
  ): SnapshotState<T> | undefined {
    return this.fixtureSnapshots.get(`${userId}:${kind}:${semesterId}`) as
      SnapshotState<T> | undefined;
  }

  async deleteUser(userId: string): Promise<void> {
    if (environment().APP_MODE === 'fixture') {
      for (const [key, user] of this.fixtureUsers)
        if (user.id === userId) this.fixtureUsers.delete(key);
      return;
    }
    await this.database.db().delete(users).where(eq(users.id, userId));
  }
}
