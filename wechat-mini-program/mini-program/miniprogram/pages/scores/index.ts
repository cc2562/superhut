import type { ScoresResponse } from '@superhut/api-contract';
import { api, toastRequestError } from '../../services/api';

interface ScoreView {
  courseName: string;
  score: string;
  detail: string;
}
interface SemesterOption {
  id: string;
  label: string;
}

Page({
  data: {
    loading: true,
    options: [] as SemesterOption[],
    range: [] as string[],
    selectedIndex: 0,
    selectedLabel: '全部学期',
    scores: [] as ScoreView[],
    summary: { earnedCredits: '-', totalGradePoints: '-', averageGradePoint: '-' },
  },
  async onLoad() {
    try {
      const semesters = await api.semesters();
      const options: SemesterOption[] = [
        { id: '', label: '全部学期' },
        ...semesters.map((semester) => ({ id: semester.id, label: semester.name || semester.id })),
      ];
      const currentIndex = options.findIndex(
        (option, index) => index > 0 && semesters[index - 1]?.current,
      );
      const selectedIndex = currentIndex > 0 ? currentIndex : 0;
      this.setData({
        options,
        range: options.map((option) => option.label),
        selectedIndex,
        selectedLabel: options[selectedIndex]?.label ?? '全部学期',
      });
    } catch (error) {
      toastRequestError(error, '加载失败');
    } finally {
      this.setData({ loading: false });
    }
    await this.loadScores();
  },
  onSemesterChange(event: WechatMiniprogram.PickerChange) {
    const index = Number(event.detail.value);
    const option = this.data.options[index];
    if (!option) return;
    this.setData({ selectedIndex: index, selectedLabel: option.label });
    void this.loadScores();
  },
  async loadScores() {
    this.setData({ loading: true });
    try {
      const option = this.data.options[this.data.selectedIndex];
      const result: ScoresResponse = await api.scores(option?.id ?? '');
      const scores = result.scores.map((row) => ({
        courseName: row.courseName,
        score: row.score,
        detail: `${row.courseNature} · ${row.credit ?? '-'} 学分 · 绩点 ${row.gradePoint ?? '-'}`,
      }));
      this.setData({
        scores,
        summary: {
          earnedCredits: result.summary.earnedCredits || '-',
          totalGradePoints: result.summary.totalGradePoints || '-',
          averageGradePoint: result.summary.averageGradePoint || '-',
        },
      });
    } catch (error) {
      toastRequestError(error, '加载失败');
    } finally {
      this.setData({ loading: false });
    }
  },
});
