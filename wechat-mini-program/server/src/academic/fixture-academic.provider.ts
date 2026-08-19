import { Injectable } from '@nestjs/common';
import type { Timetable } from '@superhut/api-contract';
import type {
  AcademicAccount,
  AcademicProvider,
  BuildingDto,
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
}
