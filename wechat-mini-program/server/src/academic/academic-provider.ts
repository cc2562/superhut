import type { Timetable } from '@superhut/api-contract';

export interface AcademicAccount {
  token: string;
  displayName: string;
  academyName?: string;
  className?: string;
  entranceYear?: string;
}
export interface SemesterDto {
  id: string;
  name: string;
  current: boolean;
}
export interface ScoreDto {
  courseName: string;
  courseAttribute: string;
  courseNature: string;
  examName: string;
  examNature: string;
  score: string;
  passed: boolean;
  gradePoint: number | null;
  credit: number | null;
}
export interface ExamDto {
  courseName: string;
  date: string;
  time: string;
  location: string;
  seat?: string;
}
export interface BuildingDto {
  id: string;
  name: string;
}
export interface FreeRoomDto {
  id: string;
  name: string;
}

export interface AcademicProvider {
  login(studentId: string, password: string): Promise<AcademicAccount>;
  validateToken(token: string): Promise<boolean>;
  semesters(token: string): Promise<SemesterDto[]>;
  refreshTimetable(token: string): Promise<Timetable>;
  scores(token: string, semesterId: string): Promise<ScoreDto[]>;
  exams(token: string): Promise<ExamDto[]>;
  buildings(token: string): Promise<BuildingDto[]>;
  freeRooms(
    token: string,
    input: { date: string; nodeId: string; buildingId: string },
  ): Promise<FreeRoomDto[]>;
}
