import { api } from '../../services/api';

interface ScoreView {
  courseName: string;
  score: string;
  detail: string;
}
Page({
  data: {
    loading: true,
    semesters: [] as Array<{ id: string; name: string; current: boolean }>,
    selectedId: '',
    scores: [] as ScoreView[],
  },
  async onLoad() {
    try {
      const semesters = await api.semesters();
      const selectedId = semesters.find(({ current }) => current)?.id ?? semesters[0]?.id ?? '';
      this.setData({ semesters, selectedId });
      await this.loadScores();
    } catch (error) {
      wx.showToast({ title: error instanceof Error ? error.message : '加载失败', icon: 'none' });
    } finally {
      this.setData({ loading: false });
    }
  },
  async loadScores() {
    const rows = await api.scores(this.data.selectedId);
    const scores = rows.map((row) => ({
      courseName: String(row.courseName ?? ''),
      score: String(row.score ?? ''),
      detail: `${String(row.courseNature ?? '')} · ${String(row.credit ?? '-')} 学分 · 绩点 ${String(row.gradePoint ?? '-')}`,
    }));
    this.setData({ scores });
  },
});
