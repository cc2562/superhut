import {
  datetime,
  index,
  int,
  json,
  longtext,
  mysqlEnum,
  mysqlTable,
  primaryKey,
  text,
  uniqueIndex,
  varchar,
} from 'drizzle-orm/mysql-core';

const timestamps = {
  createdAt: datetime('created_at', { mode: 'date', fsp: 3 }).notNull(),
  updatedAt: datetime('updated_at', { mode: 'date', fsp: 3 }).notNull(),
};

export const users = mysqlTable(
  'users',
  {
    id: varchar('id', { length: 36 }).primaryKey(),
    openidHash: varchar('openid_hash', { length: 64 }).notNull(),
    openidCiphertext: text('openid_ciphertext').notNull(),
    unionidCiphertext: text('unionid_ciphertext'),
    status: mysqlEnum('status', ['active', 'deleted', 'blocked']).notNull().default('active'),
    ...timestamps,
    deletedAt: datetime('deleted_at', { mode: 'date', fsp: 3 }),
  },
  (table) => [uniqueIndex('users_openid_hash_uq').on(table.openidHash)],
);

export const academicBindings = mysqlTable(
  'academic_bindings',
  {
    id: varchar('id', { length: 36 }).primaryKey(),
    userId: varchar('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    studentIdHash: varchar('student_id_hash', { length: 64 }).notNull(),
    studentIdCiphertext: text('student_id_ciphertext').notNull(),
    tokenCiphertext: text('token_ciphertext').notNull(),
    tokenKeyVersion: varchar('token_key_version', { length: 32 }).notNull(),
    displayName: varchar('display_name', { length: 128 }),
    academyName: varchar('academy_name', { length: 256 }),
    className: varchar('class_name', { length: 256 }),
    entranceYear: varchar('entrance_year', { length: 16 }),
    status: mysqlEnum('status', ['active', 'expired', 'unbound']).notNull().default('active'),
    lastVerifiedAt: datetime('last_verified_at', { mode: 'date', fsp: 3 }),
    ...timestamps,
  },
  (table) => [
    uniqueIndex('academic_bindings_user_uq').on(table.userId),
    index('academic_bindings_student_hash_idx').on(table.studentIdHash),
  ],
);

export const sessions = mysqlTable(
  'sessions',
  {
    id: varchar('id', { length: 36 }).primaryKey(),
    userId: varchar('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    accessTokenHash: varchar('access_token_hash', { length: 64 }).notNull(),
    refreshTokenHash: varchar('refresh_token_hash', { length: 64 }).notNull(),
    accessExpiresAt: datetime('access_expires_at', { mode: 'date', fsp: 3 }).notNull(),
    refreshExpiresAt: datetime('refresh_expires_at', { mode: 'date', fsp: 3 }).notNull(),
    revokedAt: datetime('revoked_at', { mode: 'date', fsp: 3 }),
    createdAt: datetime('created_at', { mode: 'date', fsp: 3 }).notNull(),
  },
  (table) => [
    uniqueIndex('sessions_access_hash_uq').on(table.accessTokenHash),
    uniqueIndex('sessions_refresh_hash_uq').on(table.refreshTokenHash),
    index('sessions_user_idx').on(table.userId),
  ],
);

export const academicSnapshots = mysqlTable(
  'academic_snapshots',
  {
    id: varchar('id', { length: 36 }).primaryKey(),
    userId: varchar('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    kind: mysqlEnum('kind', ['timetable', 'scores', 'exams']).notNull(),
    semesterId: varchar('semester_id', { length: 128 }).notNull().default(''),
    payloadCiphertext: longtext('payload_ciphertext').notNull(),
    sourceUpdatedAt: datetime('source_updated_at', { mode: 'date', fsp: 3 }),
    fetchedAt: datetime('fetched_at', { mode: 'date', fsp: 3 }).notNull(),
    expiresAt: datetime('expires_at', { mode: 'date', fsp: 3 }).notNull(),
  },
  (table) => [
    uniqueIndex('academic_snapshots_lookup_uq').on(table.userId, table.kind, table.semesterId),
  ],
);

export const privacyConsents = mysqlTable(
  'privacy_consents',
  {
    userId: varchar('user_id', { length: 36 })
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    version: varchar('version', { length: 32 }).notNull(),
    acceptedAt: datetime('accepted_at', { mode: 'date', fsp: 3 }).notNull(),
  },
  (table) => [primaryKey({ columns: [table.userId, table.version] })],
);

export const auditEvents = mysqlTable(
  'audit_events',
  {
    id: varchar('id', { length: 36 }).primaryKey(),
    anonymousUserId: varchar('anonymous_user_id', { length: 64 }),
    eventType: varchar('event_type', { length: 128 }).notNull(),
    result: varchar('result', { length: 32 }).notNull(),
    requestId: varchar('request_id', { length: 128 }).notNull(),
    upstreamStatusClass: varchar('upstream_status_class', { length: 16 }),
    metadata: json('metadata').$type<Record<string, string>>(),
    createdAt: datetime('created_at', { mode: 'date', fsp: 3 }).notNull(),
  },
  (table) => [index('audit_events_created_at_idx').on(table.createdAt)],
);

export const rateLimits = mysqlTable('rate_limits', {
  key: varchar('key', { length: 128 }).primaryKey(),
  attempts: int('attempts').notNull(),
  resetsAt: datetime('resets_at', { mode: 'date', fsp: 3 }).notNull(),
  updatedAt: datetime('updated_at', { mode: 'date', fsp: 3 }).notNull(),
});

export const runtimeCache = mysqlTable('runtime_cache', {
  key: varchar('key', { length: 255 }).primaryKey(),
  payload: longtext('payload').notNull(),
  expiresAt: datetime('expires_at', { mode: 'date', fsp: 3 }).notNull(),
  updatedAt: datetime('updated_at', { mode: 'date', fsp: 3 }).notNull(),
});
