import { Injectable } from '@nestjs/common';
import type { Timetable } from '@superhut/api-contract';
import type {
  AcademicAccount,
  AcademicProvider,
  BuildingDto,
  EvaluationBatchDto,
  EvaluationItemDto,
  EvaluationQuestionDto,
  EvaluationSubmissionDto,
  ExamDto,
  FreeRoomDto,
  ScoreDto,
  SemesterDto,
} from './academic-provider.js';

const timetable: Timetable = {
  semesterId: '2026-2027-1',
  firstWeek: 1,
  maxWeek: 20,
  firstDay: '2026-08-17',
  coursesByDate: {
    '2026-08-18': [
      {
        id: 'course_fixture_math',
        name: '高等数学',
        teacherName: '张老师',
        weekDuration: '1-16',
        location: '公共楼 101',
        startSection: 1,
        duration: 2,
        isExperiment: false,
      },
      {
        id: 'course_fixture_design',
        name: '包装设计实验',
        teacherName: '李老师',
        weekDuration: '1-8',
        location: '实验楼 302',
        startSection: 5,
        duration: 2,
        isExperiment: true,
      },
    ],
    '2026-08-19': [
      {
        id: 'course_fixture_english',
        name: '大学英语',
        teacherName: '王老师',
        weekDuration: '1-16',
        location: '外语楼 206',
        startSection: 3,
        duration: 2,
        isExperiment: false,
      },
    ],
  },
};

@Injectable()
export class FixtureAcademicProvider implements AcademicProvider {
  private readonly fixtureSubmitted = new Set<string>(['fixture-course-done']);
  private readonly fixtureCourses: Array<{
    courseId: string;
    courseName: string;
    courseNumber: string;
    teacherName: string;
    evaluationCategoriesId: string;
    teacherId: string;
    noticeId: string;
  }> = [
    {
      courseId: 'fixture-course-done',
      courseName: '高等数学',
      courseNumber: 'MATH101',
      teacherName: '张老师',
      evaluationCategoriesId: 'cat1',
      teacherId: 't1',
      noticeId: 'n1',
    },
    {
      courseId: 'fixture-course-manual',
      courseName: '大学英语',
      courseNumber: 'ENG101',
      teacherName: '王老师',
      evaluationCategoriesId: 'cat2',
      teacherId: 't2',
      noticeId: 'n2',
    },
    {
      courseId: 'fixture-course-auto',
      courseName: '数据结构',
      courseNumber: 'CS201',
      teacherName: '李老师',
      evaluationCategoriesId: 'cat3',
      teacherId: 't3',
      noticeId: 'n3',
    },
    {
      courseId: 'fixture-course-batch',
      courseName: '操作系统',
      courseNumber: 'CS202',
      teacherName: '赵老师',
      evaluationCategoriesId: 'cat4',
      teacherId: 't4',
      noticeId: 'n4',
    },
  ];

  async login(studentId: string, password: string): Promise<AcademicAccount> {
    await Promise.resolve();
    if (!studentId || !password) throw new Error('fixture credentials are required');
    return {
      token: 'fixture-academic-token',
      displayName: '测试同学',
      academyName: '测试学院',
      className: '测试班级',
      entranceYear: '2023',
    };
  }
  async validateToken(token: string): Promise<boolean> {
    await Promise.resolve();
    return token === 'fixture-academic-token';
  }
  async semesters(): Promise<SemesterDto[]> {
    return [{ id: '2026-2027-1', name: '2026-2027 学年第一学期', current: true }];
  }
  async refreshTimetable(): Promise<Timetable> {
    return structuredClone(timetable);
  }
  async scores(): Promise<ScoreDto[]> {
    return [
      {
        courseName: '高等数学',
        courseAttribute: '必修',
        courseNature: '专业基础课',
        examName: '期末考试',
        examNature: '正常考试',
        score: '88',
        passed: true,
        gradePoint: 3.8,
        credit: 4,
      },
    ];
  }
  async exams(): Promise<ExamDto[]> {
    return [
      {
        courseName: '高等数学',
        date: '2026-12-28',
        time: '09:00-11:00',
        location: '公共楼 101',
        seat: '18',
      },
    ];
  }
  async buildings(): Promise<BuildingDto[]> {
    return [
      { id: 'public', name: '公共教学楼' },
      { id: 'foreign', name: '外语楼' },
    ];
  }
  async freeRooms(_token: string, input: { buildingId: string }): Promise<FreeRoomDto[]> {
    return [
      { id: `${input.buildingId}-101`, name: '101' },
      { id: `${input.buildingId}-203`, name: '203' },
    ];
  }
  async evaluationBatches(): Promise<EvaluationBatchDto[]> {
    return [
      {
        id: 'fixture-batch',
        name: '2026-2027 学年第一学期评教',
        category: '理论课',
        semesterName: '2026-2027 学年第一学期',
        pj01id: 'pj01',
        pj05id: 'pj05',
      },
    ];
  }
  async evaluationList(): Promise<EvaluationItemDto[]> {
    return this.fixtureCourses.map((course) => ({
      ...course,
      submitted: this.fixtureSubmitted.has(course.courseId),
    }));
  }
  async evaluationQuestions(): Promise<EvaluationQuestionDto[]> {
    return [
      {
        id: 'q1',
        name: '教学态度是否认真',
        options: [
          { id: 'q1-a', name: '非常认真', score: 5 },
          { id: 'q1-b', name: '较认真', score: 4.5 },
          { id: 'q1-c', name: '一般', score: 4 },
        ],
      },
      {
        id: 'q2',
        name: '教学内容是否充实',
        options: [
          { id: 'q2-a', name: '非常充实', score: 5 },
          { id: 'q2-b', name: '较充实', score: 4.5 },
        ],
      },
    ];
  }
  async submitEvaluation(_token: string, submission: EvaluationSubmissionDto): Promise<void> {
    this.fixtureSubmitted.add(submission.courseId);
  }
}
