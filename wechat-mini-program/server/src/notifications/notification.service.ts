import { Inject, Injectable } from '@nestjs/common';
import { and, count, desc, eq, gt, isNull, lte, or, sql } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import type {
  AdminAnnouncement,
  AdminAnnouncementPage,
  Announcement,
  AnnouncementActionPath,
  AnnouncementCreateRequest,
  AnnouncementPage,
  AnnouncementPublishRequest,
  AnnouncementStatus,
  AnnouncementSummary,
  AnnouncementUpdateRequest,
} from '@superhut/api-contract';
import { ApiError } from '../common/api-error.js';
import { environment } from '../config.js';
import { DatabaseService } from '../database/database.service.js';
import { announcementReads, announcements } from '../database/schema.js';

interface FixtureAnnouncement {
  id: string;
  title: string;
  summary: string;
  content: string;
  status: AnnouncementStatus;
  actionPath: string | null;
  publishAt: Date | null;
  expiresAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const PAGE_SIZE = 20;

@Injectable()
export class NotificationService {
  private readonly fixtureAnnouncements = new Map<string, FixtureAnnouncement>();
  private readonly fixtureReads = new Map<string, Date>();

  constructor(@Inject(DatabaseService) private readonly database: DatabaseService) {}

  isAdmin(userId: string): boolean {
    const configured = environment()
      .ADMIN_USER_IDS.split(',')
      .map((value) => value.trim())
      .filter(Boolean);
    return (
      configured.includes(userId) ||
      (environment().APP_MODE === 'fixture' && configured.includes('*'))
    );
  }

  requireAdmin(userId: string): void {
    if (!this.isAdmin(userId)) throw new ApiError('AUTH_FORBIDDEN', 403, '没有通知管理权限');
  }

  async summary(userId: string): Promise<AnnouncementSummary> {
    if (environment().APP_MODE === 'fixture') {
      const visible = this.fixtureVisible(userId);
      return {
        latest: visible[0] ?? null,
        unreadCount: visible.filter(({ read }) => !read).length,
      };
    }
    await this.promoteScheduled();
    const now = new Date();
    const visible = this.visibility(now);
    const [latest] = await this.database
      .db()
      .select({ announcement: announcements, readAt: announcementReads.readAt })
      .from(announcements)
      .leftJoin(
        announcementReads,
        and(
          eq(announcementReads.announcementId, announcements.id),
          eq(announcementReads.userId, userId),
        ),
      )
      .where(visible)
      .orderBy(desc(sql`${announcementReads.readAt} is null`), desc(announcements.publishAt))
      .limit(1);
    const [unread] = await this.database
      .db()
      .select({ value: count() })
      .from(announcements)
      .leftJoin(
        announcementReads,
        and(
          eq(announcementReads.announcementId, announcements.id),
          eq(announcementReads.userId, userId),
        ),
      )
      .where(and(visible, isNull(announcementReads.readAt)));
    return {
      latest: latest ? this.userDto(latest.announcement, latest.readAt !== null) : null,
      unreadCount: Number(unread?.value ?? 0),
    };
  }

  async list(userId: string, cursor?: string): Promise<AnnouncementPage> {
    const offset = this.decodeCursor(cursor);
    if (environment().APP_MODE === 'fixture') {
      const items = this.fixtureVisible(userId).slice(offset, offset + PAGE_SIZE);
      return {
        items,
        nextCursor: items.length === PAGE_SIZE ? this.encodeCursor(offset + PAGE_SIZE) : null,
      };
    }
    await this.promoteScheduled();
    const rows = await this.database
      .db()
      .select({ announcement: announcements, readAt: announcementReads.readAt })
      .from(announcements)
      .leftJoin(
        announcementReads,
        and(
          eq(announcementReads.announcementId, announcements.id),
          eq(announcementReads.userId, userId),
        ),
      )
      .where(this.visibility(new Date()))
      .orderBy(
        desc(sql`${announcementReads.readAt} is null`),
        desc(announcements.publishAt),
        desc(announcements.id),
      )
      .limit(PAGE_SIZE)
      .offset(offset);
    const items = rows.map(({ announcement, readAt }) =>
      this.userDto(announcement, readAt !== null),
    );
    return {
      items,
      nextCursor: items.length === PAGE_SIZE ? this.encodeCursor(offset + PAGE_SIZE) : null,
    };
  }

  async detail(userId: string, announcementId: string): Promise<Announcement> {
    if (environment().APP_MODE === 'fixture') {
      const item = this.fixtureVisible(userId).find(({ id }) => id === announcementId);
      if (!item) throw new ApiError('RESOURCE_NOT_FOUND', 404, '通知不存在或已不可见');
      return item;
    }
    await this.promoteScheduled();
    const [row] = await this.database
      .db()
      .select({ announcement: announcements, readAt: announcementReads.readAt })
      .from(announcements)
      .leftJoin(
        announcementReads,
        and(
          eq(announcementReads.announcementId, announcements.id),
          eq(announcementReads.userId, userId),
        ),
      )
      .where(and(eq(announcements.id, announcementId), this.visibility(new Date())))
      .limit(1);
    if (!row) throw new ApiError('RESOURCE_NOT_FOUND', 404, '通知不存在或已不可见');
    return this.userDto(row.announcement, row.readAt !== null);
  }

  async markRead(userId: string, announcementId: string): Promise<void> {
    await this.detail(userId, announcementId);
    const now = new Date();
    if (environment().APP_MODE === 'fixture') {
      const key = `${announcementId}:${userId}`;
      if (!this.fixtureReads.has(key)) this.fixtureReads.set(key, now);
      return;
    }
    await this.database
      .db()
      .insert(announcementReads)
      .values({ announcementId, userId, readAt: now })
      .onDuplicateKeyUpdate({ set: { readAt: sql`${announcementReads.readAt}` } });
  }

  forgetFixtureUser(userId: string): void {
    if (environment().APP_MODE !== 'fixture') return;
    for (const key of this.fixtureReads.keys()) {
      if (key.endsWith(`:${userId}`)) this.fixtureReads.delete(key);
    }
  }

  async adminList(userId: string, cursor?: string): Promise<AdminAnnouncementPage> {
    this.requireAdmin(userId);
    const offset = this.decodeCursor(cursor);
    if (environment().APP_MODE === 'fixture') {
      this.fixturePromoteScheduled();
      const rows = [...this.fixtureAnnouncements.values()]
        .sort((left, right) => right.updatedAt.getTime() - left.updatedAt.getTime())
        .slice(offset, offset + PAGE_SIZE)
        .map((item) => this.adminDto(item));
      return {
        items: rows,
        nextCursor: rows.length === PAGE_SIZE ? this.encodeCursor(offset + PAGE_SIZE) : null,
      };
    }
    await this.promoteScheduled();
    const rows = await this.database
      .db()
      .select()
      .from(announcements)
      .orderBy(desc(announcements.updatedAt), desc(announcements.id))
      .limit(PAGE_SIZE)
      .offset(offset);
    return {
      items: rows.map((item) => this.adminDto(item)),
      nextCursor: rows.length === PAGE_SIZE ? this.encodeCursor(offset + PAGE_SIZE) : null,
    };
  }

  async adminDetail(userId: string, announcementId: string): Promise<AdminAnnouncement> {
    this.requireAdmin(userId);
    if (environment().APP_MODE === 'fixture') {
      this.fixturePromoteScheduled();
      const item = this.fixtureAnnouncements.get(announcementId);
      if (!item) throw new ApiError('RESOURCE_NOT_FOUND', 404, '公告不存在');
      return this.adminDto(item);
    }
    await this.promoteScheduled();
    const [item] = await this.database
      .db()
      .select()
      .from(announcements)
      .where(eq(announcements.id, announcementId))
      .limit(1);
    if (!item) throw new ApiError('RESOURCE_NOT_FOUND', 404, '公告不存在');
    return this.adminDto(item);
  }

  async create(userId: string, input: AnnouncementCreateRequest): Promise<AdminAnnouncement> {
    this.requireAdmin(userId);
    const now = new Date();
    const item: FixtureAnnouncement = {
      id: randomUUID(),
      title: input.title,
      summary: input.summary,
      content: input.content,
      status: 'draft',
      actionPath: input.actionPath,
      publishAt: null,
      expiresAt: input.expiresAt ? new Date(input.expiresAt) : null,
      createdAt: now,
      updatedAt: now,
    };
    if (environment().APP_MODE === 'fixture') this.fixtureAnnouncements.set(item.id, item);
    else {
      await this.database
        .db()
        .insert(announcements)
        .values({
          ...item,
          createdByUserId: userId,
        });
    }
    return this.adminDto(item);
  }

  async update(
    userId: string,
    announcementId: string,
    input: AnnouncementUpdateRequest,
  ): Promise<AdminAnnouncement> {
    const current = await this.adminDetail(userId, announcementId);
    if (current.status === 'withdrawn')
      throw new ApiError('VALIDATION_ERROR', 400, '已撤回公告不可编辑');
    const expiresAt = input.expiresAt === undefined ? current.expiresAt : input.expiresAt;
    if (current.publishAt && expiresAt && Date.parse(expiresAt) <= Date.parse(current.publishAt)) {
      throw new ApiError('VALIDATION_ERROR', 400, '过期时间必须晚于发布时间');
    }
    const updatedAt = new Date();
    if (environment().APP_MODE === 'fixture') {
      const item = this.fixtureAnnouncements.get(announcementId);
      if (!item) throw new ApiError('RESOURCE_NOT_FOUND', 404, '公告不存在');
      if (input.title !== undefined) item.title = input.title;
      if (input.summary !== undefined) item.summary = input.summary;
      if (input.content !== undefined) item.content = input.content;
      if (input.actionPath !== undefined) item.actionPath = input.actionPath;
      if (input.expiresAt !== undefined)
        item.expiresAt = input.expiresAt ? new Date(input.expiresAt) : null;
      item.updatedAt = updatedAt;
      return this.adminDto(item);
    }
    await this.database
      .db()
      .update(announcements)
      .set({
        ...(input.title !== undefined ? { title: input.title } : {}),
        ...(input.summary !== undefined ? { summary: input.summary } : {}),
        ...(input.content !== undefined ? { content: input.content } : {}),
        ...(input.actionPath !== undefined ? { actionPath: input.actionPath } : {}),
        ...(input.expiresAt !== undefined
          ? { expiresAt: input.expiresAt ? new Date(input.expiresAt) : null }
          : {}),
        updatedAt,
      })
      .where(eq(announcements.id, announcementId));
    return this.adminDetail(userId, announcementId);
  }

  async publish(
    userId: string,
    announcementId: string,
    input: AnnouncementPublishRequest,
  ): Promise<AdminAnnouncement> {
    const current = await this.adminDetail(userId, announcementId);
    if (current.status === 'withdrawn')
      throw new ApiError('VALIDATION_ERROR', 400, '已撤回公告不可重新发布');
    const publishAt = new Date(input.publishAt);
    const status: AnnouncementStatus = publishAt.getTime() > Date.now() ? 'scheduled' : 'published';
    const expiresAt = input.expiresAt ? new Date(input.expiresAt) : null;
    const updatedAt = new Date();
    if (environment().APP_MODE === 'fixture') {
      const item = this.fixtureAnnouncements.get(announcementId);
      if (!item) throw new ApiError('RESOURCE_NOT_FOUND', 404, '公告不存在');
      Object.assign(item, { publishAt, expiresAt, status, updatedAt });
      return this.adminDto(item);
    }
    await this.database
      .db()
      .update(announcements)
      .set({ publishAt, expiresAt, status, updatedAt })
      .where(eq(announcements.id, announcementId));
    return this.adminDetail(userId, announcementId);
  }

  async withdraw(userId: string, announcementId: string): Promise<AdminAnnouncement> {
    const current = await this.adminDetail(userId, announcementId);
    if (current.status === 'withdrawn') return current;
    const updatedAt = new Date();
    if (environment().APP_MODE === 'fixture') {
      const item = this.fixtureAnnouncements.get(announcementId);
      if (!item) throw new ApiError('RESOURCE_NOT_FOUND', 404, '公告不存在');
      item.status = 'withdrawn';
      item.updatedAt = updatedAt;
      return this.adminDto(item);
    }
    await this.database
      .db()
      .update(announcements)
      .set({ status: 'withdrawn', updatedAt })
      .where(eq(announcements.id, announcementId));
    return this.adminDetail(userId, announcementId);
  }

  private visibility(now: Date) {
    return and(
      eq(announcements.status, 'published'),
      lte(announcements.publishAt, now),
      or(isNull(announcements.expiresAt), gt(announcements.expiresAt, now)),
    );
  }

  private async promoteScheduled(): Promise<void> {
    await this.database
      .db()
      .update(announcements)
      .set({ status: 'published' })
      .where(and(eq(announcements.status, 'scheduled'), lte(announcements.publishAt, new Date())));
  }

  private fixturePromoteScheduled(): void {
    const now = Date.now();
    for (const item of this.fixtureAnnouncements.values()) {
      if (item.status === 'scheduled' && item.publishAt && item.publishAt.getTime() <= now)
        item.status = 'published';
    }
  }

  private fixtureVisible(userId: string): Announcement[] {
    this.fixturePromoteScheduled();
    const now = Date.now();
    return [...this.fixtureAnnouncements.values()]
      .filter(
        (item) =>
          item.status === 'published' &&
          Boolean(item.publishAt && item.publishAt.getTime() <= now) &&
          (!item.expiresAt || item.expiresAt.getTime() > now),
      )
      .map((item) => this.userDto(item, this.fixtureReads.has(`${item.id}:${userId}`)))
      .sort((left, right) => {
        if (left.read !== right.read) return left.read ? 1 : -1;
        return Date.parse(right.publishAt) - Date.parse(left.publishAt);
      });
  }

  private userDto(
    item: Omit<FixtureAnnouncement, 'status' | 'createdAt'> & { publishAt: Date | null },
    read: boolean,
  ): Announcement {
    if (!item.publishAt) throw new Error('visible announcement must have publishAt');
    return {
      id: item.id,
      title: item.title,
      summary: item.summary,
      content: item.content,
      actionPath: this.actionPath(item.actionPath),
      publishAt: item.publishAt.toISOString(),
      expiresAt: item.expiresAt?.toISOString() ?? null,
      updatedAt: item.updatedAt.toISOString(),
      read,
    };
  }

  private adminDto(item: FixtureAnnouncement): AdminAnnouncement {
    return {
      id: item.id,
      title: item.title,
      summary: item.summary,
      content: item.content,
      status: item.status,
      actionPath: this.actionPath(item.actionPath),
      publishAt: item.publishAt?.toISOString() ?? null,
      expiresAt: item.expiresAt?.toISOString() ?? null,
      createdAt: item.createdAt.toISOString(),
      updatedAt: item.updatedAt.toISOString(),
    };
  }

  private decodeCursor(cursor?: string): number {
    if (!cursor) return 0;
    const value = Number(Buffer.from(cursor, 'base64url').toString('utf8'));
    if (!Number.isSafeInteger(value) || value < 0)
      throw new ApiError('VALIDATION_ERROR', 400, '分页参数不正确');
    return value;
  }

  private encodeCursor(offset: number): string {
    return Buffer.from(String(offset), 'utf8').toString('base64url');
  }

  private actionPath(value: string | null): AnnouncementActionPath | null {
    const allowed: AnnouncementActionPath[] = [
      '/pages/timetable/index',
      '/pages/scores/index',
      '/pages/exams/index',
      '/pages/rooms/index',
      '/pages/evaluation/batches/index',
      '/pages/agreement/index',
    ];
    return allowed.find((path) => path === value) ?? null;
  }
}
