import type { AdminAnnouncement, AnnouncementActionPath } from '@superhut/api-contract';
import { api, toastRequestError } from '../../../services/api';

const actionOptions: Array<{ label: string; path: AnnouncementActionPath | null }> = [
  { label: '无跳转', path: null },
  { label: '课表', path: '/pages/timetable/index' },
  { label: '成绩', path: '/pages/scores/index' },
  { label: '考试', path: '/pages/exams/index' },
  { label: '空教室', path: '/pages/rooms/index' },
  { label: '学生评教', path: '/pages/evaluation/batches/index' },
  { label: '服务协议', path: '/pages/agreement/index' },
];

function datePart(value: Date): string {
  return `${value.getFullYear()}-${String(value.getMonth() + 1).padStart(2, '0')}-${String(value.getDate()).padStart(2, '0')}`;
}
function timePart(value: Date): string {
  return `${String(value.getHours()).padStart(2, '0')}:${String(value.getMinutes()).padStart(2, '0')}`;
}
function iso(date: string, time: string): string {
  return new Date(`${date}T${time}:00`).toISOString();
}

Page({
  data: {
    id: '',
    status: 'draft' as AdminAnnouncement['status'],
    title: '',
    summary: '',
    content: '',
    actionOptions,
    actionLabels: actionOptions.map(({ label }) => label),
    actionIndex: 0,
    publishNow: true,
    publishDate: datePart(new Date()),
    publishTime: timePart(new Date()),
    hasExpiration: false,
    expiresDate: datePart(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)),
    expiresTime: '23:59',
    loading: false,
    loadingItem: false,
    previewVisible: false,
  },
  async onLoad(options: Record<string, string | undefined>) {
    const id = options.id ?? '';
    if (!id) return;
    this.setData({ id, loadingItem: true });
    try {
      const item = await api.adminNotification(id);
      const publishAt = item.publishAt ? new Date(item.publishAt) : new Date();
      const expiresAt = item.expiresAt ? new Date(item.expiresAt) : null;
      const actionIndex = Math.max(
        0,
        actionOptions.findIndex(({ path }) => path === item.actionPath),
      );
      this.setData({
        status: item.status,
        title: item.title,
        summary: item.summary,
        content: item.content,
        actionIndex,
        publishNow: item.status === 'draft' || publishAt.getTime() <= Date.now(),
        publishDate: datePart(publishAt),
        publishTime: timePart(publishAt),
        hasExpiration: Boolean(expiresAt),
        ...(expiresAt
          ? { expiresDate: datePart(expiresAt), expiresTime: timePart(expiresAt) }
          : {}),
      });
    } catch (error) {
      toastRequestError(error, '公告加载失败');
    } finally {
      this.setData({ loadingItem: false });
    }
  },
  onTitle(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ title: event.detail.value });
  },
  onSummary(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ summary: event.detail.value });
  },
  onContent(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ content: event.detail.value });
  },
  onAction(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ actionIndex: Number(event.detail.value) });
  },
  onPublishNow(event: WechatMiniprogram.CustomEvent<{ value: boolean }>) {
    this.setData({ publishNow: event.detail.value });
  },
  onExpiration(event: WechatMiniprogram.CustomEvent<{ value: boolean }>) {
    this.setData({ hasExpiration: event.detail.value });
  },
  onPublishDate(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ publishDate: event.detail.value });
  },
  onPublishTime(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ publishTime: event.detail.value });
  },
  onExpiresDate(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ expiresDate: event.detail.value });
  },
  onExpiresTime(event: WechatMiniprogram.CustomEvent<{ value: string }>) {
    this.setData({ expiresTime: event.detail.value });
  },
  togglePreview() {
    this.setData({ previewVisible: !this.data.previewVisible });
  },
  validate(): boolean {
    if (!this.data.title.trim() || !this.data.summary.trim() || !this.data.content.trim()) {
      wx.showToast({ title: '请完整填写标题、摘要和正文', icon: 'none' });
      return false;
    }
    return true;
  },
  async save(showToast = true): Promise<string> {
    if (!this.validate()) return '';
    const actionPath = actionOptions[this.data.actionIndex]?.path ?? null;
    const input = {
      title: this.data.title.trim(),
      summary: this.data.summary.trim(),
      content: this.data.content.trim(),
      actionPath,
      expiresAt: this.data.hasExpiration ? iso(this.data.expiresDate, this.data.expiresTime) : null,
    };
    const item = this.data.id
      ? await api.updateAnnouncement(this.data.id, input)
      : await api.createAnnouncement(input);
    this.setData({ id: item.id, status: item.status });
    if (showToast)
      wx.showToast({
        title: item.status === 'draft' ? '草稿已保存' : '修改已保存',
        icon: 'success',
      });
    return item.id;
  },
  async saveDraft() {
    if (this.data.loading || this.data.status === 'withdrawn') return;
    this.setData({ loading: true });
    try {
      await this.save();
    } catch (error) {
      toastRequestError(error, '保存失败');
    } finally {
      this.setData({ loading: false });
    }
  },
  async publish() {
    if (this.data.loading || this.data.status === 'withdrawn') return;
    this.setData({ loading: true });
    try {
      const id = await this.save(false);
      if (!id) return;
      const publishAt = this.data.publishNow
        ? new Date().toISOString()
        : iso(this.data.publishDate, this.data.publishTime);
      const expiresAt = this.data.hasExpiration
        ? iso(this.data.expiresDate, this.data.expiresTime)
        : null;
      if (expiresAt && Date.parse(expiresAt) <= Date.parse(publishAt)) {
        wx.showToast({ title: '过期时间必须晚于发布时间', icon: 'none' });
        return;
      }
      const item = await api.publishAnnouncement(id, { publishAt, expiresAt });
      this.setData({ status: item.status });
      wx.showToast({
        title: item.status === 'scheduled' ? '已安排发布' : '已发布',
        icon: 'success',
      });
      setTimeout(() => void wx.navigateBack(), 500);
    } catch (error) {
      toastRequestError(error, '发布失败');
    } finally {
      this.setData({ loading: false });
    }
  },
});
