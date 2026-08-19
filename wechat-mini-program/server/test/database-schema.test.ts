import { getTableColumns, getTableName } from 'drizzle-orm';
import { describe, expect, it } from 'vitest';
import {
  academicBindings,
  academicSnapshots,
  auditEvents,
  privacyConsents,
  rateLimits,
  runtimeCache,
  sessions,
  users,
} from '../src/database/schema.js';

describe('MySQL schema safety', () => {
  const tables = [
    users,
    academicBindings,
    sessions,
    academicSnapshots,
    privacyConsents,
    auditEvents,
    rateLimits,
    runtimeCache,
  ];

  it('uses lowercase identifiers for case-sensitive MySQL 8.0', () => {
    for (const table of tables) {
      expect(getTableName(table)).toMatch(/^[a-z][a-z0-9_]*$/);
      for (const column of Object.values(getTableColumns(table)))
        expect(column.name).toMatch(/^[a-z][a-z0-9_]*$/);
    }
  });

  it('does not define password columns', () => {
    const columns = tables.flatMap((table) =>
      Object.values(getTableColumns(table)).map(({ name }) => name),
    );
    expect(columns.some((name) => name.includes('password'))).toBe(false);
  });
});
