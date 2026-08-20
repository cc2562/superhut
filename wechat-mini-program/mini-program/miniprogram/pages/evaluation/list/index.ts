import type { EvaluationItem } from '@superhut/api-contract';
import { api, toastRequestError } from '../../../services/api';

Page({
  data: {
    loading: true,
    autoLoading: false,
    batchId: '',
    pj01id: '',
    pj05id: '',
    pending: [] as EvaluationItem[],
    done: [] as EvaluationItem[],
  },
  onLoad(query: Record<string, string | undefined>) {
    this.setData({
      batchId: query.batchId ?? '',
      pj01id: query.pj01id ?? '',
      pj05id: query.pj05id ?? '',
    });
  },
  async onShow() {
    await this.load();
  },
  async load() {
    try {
      const items = await api.evaluationList({
        batchId: this.data.batchId,
        pj01id: this.data.pj01id,
        pj05id: this.data.pj05id,
      });
      this.setData({
        pending: items.filter((item) => !item.submitted),
        done: items.filter((item) => item.submitted),
      });
    } catch (error) {
      toastRequestError(error, '加载失败');
    } finally {
      this.setData({ loading: false });
    }
  },
  open(event: WechatMiniprogram.BaseEvent) {
    const item = this.data.pending[Number(event.currentTarget.dataset.index)];
    if (!item) return;
    void wx.navigateTo({
      url: `/pages/evaluation/form/index?batchId=${encodeURIComponent(this.data.batchId)}&courseId=${encodeURIComponent(item.courseId)}&evaluationCategoriesId=${encodeURIComponent(item.evaluationCategoriesId)}&teacherId=${encodeURIComponent(item.teacherId)}&noticeId=${encodeURIComponent(item.noticeId)}`,
    });
  },
  async autoAll() {
    const pending = this.data.pending.length;
    const confirm = await wx.showModal({
      title: '一键评完所有',
      content: `将自动为 ${pending} 门未评课程生成满分评价并提交，确认？`,
    });
    if (!confirm.confirm) return;
    this.setData({ autoLoading: true });
    try {
      const result = await api.autoSubmitAll({
        batchId: this.data.batchId,
        pj01id: this.data.pj01id,
        pj05id: this.data.pj05id,
      });
      wx.showToast({ title: `已完成 ${result.succeeded}/${result.total} 门`, icon: 'none' });
      await this.load();
    } catch (error) {
      toastRequestError(error, '操作失败');
    } finally {
      this.setData({ autoLoading: false });
    }
  },
});
