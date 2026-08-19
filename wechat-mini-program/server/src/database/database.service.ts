import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { drizzle, type MySql2Database } from 'drizzle-orm/mysql2';
import { migrate } from 'drizzle-orm/mysql2/migrator';
import mysql, { type Pool, type PoolConnection, type RowDataPacket } from 'mysql2/promise';
import { fileURLToPath } from 'node:url';
import { environment } from '../config.js';
import * as schema from './schema.js';

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private pool?: Pool;
  private client?: MySql2Database<typeof schema>;
  private readonly registeredLocks = new Map<string, () => Promise<void>>();

  async onModuleInit(): Promise<void> {
    const env = environment();
    if (env.APP_MODE === 'fixture') return;
    this.pool = mysql.createPool({
      host: env.MYSQL_HOST,
      port: env.MYSQL_PORT,
      database: env.MYSQL_DATABASE,
      user: env.MYSQL_USER,
      password: env.MYSQL_PASSWORD,
      charset: 'utf8mb4',
      timezone: 'Z',
      connectionLimit: 8,
      enableKeepAlive: true,
    });
    this.client = drizzle(this.pool, { schema, mode: 'default' });
    const [caseRows] = await this.pool.query<
      Array<RowDataPacket & { lowerCaseTableNames: number }>
    >('SELECT @@lower_case_table_names AS lowerCaseTableNames');
    if (Number(caseRows[0]?.lowerCaseTableNames) !== 0) {
      throw new Error('MySQL must use case-sensitive table names (lower_case_table_names=0)');
    }
    const [lockRows] = await this.pool.query<Array<RowDataPacket & { acquired: number }>>(
      "SELECT GET_LOCK('superhut_schema_migrate', 60) AS acquired",
    );
    if (Number(lockRows[0]?.acquired) !== 1) throw new Error('database migration lock unavailable');
    try {
      const migrationsFolder = fileURLToPath(new URL('../../drizzle', import.meta.url));
      await migrate(this.client, { migrationsFolder });
    } finally {
      await this.pool.query("SELECT RELEASE_LOCK('superhut_schema_migrate')");
    }
  }

  db(): MySql2Database<typeof schema> {
    if (!this.client) throw new Error('database is unavailable in fixture mode');
    return this.client;
  }

  async ready(): Promise<boolean> {
    if (environment().APP_MODE === 'fixture') return true;
    try {
      await this.pool?.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }

  async acquireAdvisoryLock(
    name: string,
    timeoutSeconds: number,
  ): Promise<(() => Promise<void>) | undefined> {
    if (!this.pool) return undefined;
    const connection: PoolConnection = await this.pool.getConnection();
    try {
      const [rows] = await connection.query<Array<RowDataPacket & { acquired: number }>>(
        'SELECT GET_LOCK(?, ?) AS acquired',
        [name, timeoutSeconds],
      );
      if (Number(rows[0]?.acquired) !== 1) {
        connection.release();
        return undefined;
      }
      return async () => {
        try {
          await connection.query('SELECT RELEASE_LOCK(?)', [name]);
        } finally {
          connection.release();
        }
      };
    } catch (error) {
      connection.release();
      throw error;
    }
  }

  registerLock(owner: string, release: () => Promise<void>): void {
    this.registeredLocks.set(owner, release);
  }

  async releaseRegisteredLock(owner: string): Promise<void> {
    const release = this.registeredLocks.get(owner);
    if (!release) return;
    this.registeredLocks.delete(owner);
    await release();
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.allSettled([...this.registeredLocks.values()].map((release) => release()));
    this.registeredLocks.clear();
    await this.pool?.end();
  }
}
