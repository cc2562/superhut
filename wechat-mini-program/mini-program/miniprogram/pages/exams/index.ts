import { api } from '../../services/api';
interface ExamView {
  courseName: string;
  date: string;
  detail: string;
}
Page({
  data: { loading: true, exams: [] as ExamView[] },
  async onLoad() {
    try {
      const rows = await api.exams();
      this.setData({
        exams: rows.map((row) => ({
          courseName: String(row.courseName ?? ''),
          date: String(row.date ?? ''),
          detail: `${String(row.time ?? '')} · ${String(row.location ?? '')}`,
        })),
      });
    } catch (error) {
      wx.showToast({ title: error instanceof Error ? error.message : '加载失败', icon: 'none' });
    } finally {
      this.setData({ loading: false });
    }
  },
});
