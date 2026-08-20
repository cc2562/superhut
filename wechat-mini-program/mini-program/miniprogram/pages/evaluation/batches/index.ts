import type { EvaluationBatch } from '@superhut/api-contract';
import { api, toastRequestError } from '../../../services/api';

Page({
  data: {
    loading: true,
    batches: [] as EvaluationBatch[],
  },
  async onLoad() {
    try {
      this.setData({ batches: await api.evaluationBatches() });
    } catch (error) {
      toastRequestError(error, '加载失败');
    } finally {
      this.setData({ loading: false });
    }
  },
  open(event: WechatMiniprogram.BaseEvent) {
    const batch = this.data.batches[Number(event.currentTarget.dataset.index)];
    if (!batch) return;
    void wx.navigateTo({
      url: `/pages/evaluation/list/index?batchId=${encodeURIComponent(batch.id)}&pj01id=${encodeURIComponent(batch.pj01id)}&pj05id=${encodeURIComponent(batch.pj05id)}`,
    });
  },
});
