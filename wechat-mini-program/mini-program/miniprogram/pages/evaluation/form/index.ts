import type { EvaluationTarget } from '@superhut/api-contract';
import { api, toastRequestError } from '../../../services/api';

interface OptionView {
  id: string;
  name: string;
  selected: boolean;
}
interface QuestionView {
  id: string;
  name: string;
  options: OptionView[];
}

Page({
  data: {
    loading: true,
    submitting: false,
    batchId: '',
    courseId: '',
    evaluationCategoriesId: '',
    teacherId: '',
    noticeId: '',
    questions: [] as QuestionView[],
  },
  onLoad(query: Record<string, string | undefined>) {
    this.setData({
      batchId: query.batchId ?? '',
      courseId: query.courseId ?? '',
      evaluationCategoriesId: query.evaluationCategoriesId ?? '',
      teacherId: query.teacherId ?? '',
      noticeId: query.noticeId ?? '',
    });
    void this.load();
  },
  async load() {
    try {
      const questions = await api.evaluationQuestions({
        batchId: this.data.batchId,
        courseId: this.data.courseId,
        evaluationCategoriesId: this.data.evaluationCategoriesId,
        teacherId: this.data.teacherId,
        noticeId: this.data.noticeId,
      });
      this.setData({
        questions: questions.map((question) => ({
          id: question.id,
          name: question.name,
          options: question.options.map((option) => ({
            id: option.id,
            name: option.name,
            selected: false,
          })),
        })),
      });
    } catch (error) {
      toastRequestError(error, '加载失败');
    } finally {
      this.setData({ loading: false });
    }
  },
  select(event: WechatMiniprogram.BaseEvent) {
    const questionIndex = Number(event.currentTarget.dataset.qi);
    const optionIndex = Number(event.currentTarget.dataset.oi);
    this.setData({
      questions: this.data.questions.map((question, qi) =>
        qi === questionIndex
          ? {
              ...question,
              options: question.options.map((option, oi) => ({
                ...option,
                selected: oi === optionIndex,
              })),
            }
          : question,
      ),
    });
  },
  buildTarget(): EvaluationTarget[] {
    return this.data.questions.map((question) => ({
      questionId: question.id,
      optionId: question.options.find((option) => option.selected)?.id ?? '',
    }));
  },
  async submit() {
    const target = this.buildTarget();
    if (target.some((item) => !item.optionId)) {
      wx.showToast({ title: '请完成所有题目后再提交', icon: 'none' });
      return;
    }
    await this.doSumbit(target);
  },
  async auto() {
    const confirm = await wx.showModal({
      title: '一键评教',
      content: '将自动为本科目生成满分评价并提交，确认？',
    });
    if (!confirm.confirm) return;
    await this.doSumbit(null);
  },
  async doSumbit(target: EvaluationTarget[] | null) {
    if (this.data.submitting) return;
    this.setData({ submitting: true });
    try {
      if (target) {
        await api.submitEvaluation({
          batchId: this.data.batchId,
          courseId: this.data.courseId,
          evaluationCategoriesId: this.data.evaluationCategoriesId,
          teacherId: this.data.teacherId,
          noticeId: this.data.noticeId,
          target,
        });
      } else {
        await api.autoSubmitEvaluation({
          batchId: this.data.batchId,
          courseId: this.data.courseId,
          evaluationCategoriesId: this.data.evaluationCategoriesId,
          teacherId: this.data.teacherId,
          noticeId: this.data.noticeId,
        });
      }
      wx.showToast({ title: '提交成功', icon: 'success' });
      setTimeout(() => wx.navigateBack(), 600);
    } catch (error) {
      toastRequestError(error, '提交失败');
    } finally {
      this.setData({ submitting: false });
    }
  },
});
