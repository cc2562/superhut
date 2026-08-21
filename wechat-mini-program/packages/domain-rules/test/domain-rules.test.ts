import { describe, expect, it } from 'vitest';
import type { Course } from '@superhut/api-contract';
import {
  buildWeekSlots,
  calculateSchoolWeek,
  courseColor,
  courseTimeRange,
  findNextCourses,
  moveCourseDay,
  parseStrictDate,
  stableCourseId,
} from '../src/index.js';

const course = (overrides: Partial<Course> = {}): Course => ({
  id: 'course_test',
  name: '高等数学',
  teacherName: '张老师',
  weekDuration: '1-16',
  location: '公共楼 101',
  startSection: 1,
  duration: 2,
  isExperiment: false,
  ...overrides,
});

describe('course domain rules', () => {
  it('strictly rejects normalized invalid dates', () => {
    expect(parseStrictDate('2026-02-29')).toBeNull();
    expect(parseStrictDate('2026-99-99')).toBeNull();
    expect(parseStrictDate('2026-08-18')).not.toBeNull();
  });
  it('calculates week relative to the first Monday', () => {
    expect(calculateSchoolWeek('2026-08-03', new Date(2026, 7, 17))).toBe(3);
    expect(calculateSchoolWeek('2026-08-24', new Date(2026, 7, 17))).toBe(0);
  });
  it('uses the authoritative section timetable', () => {
    const range = courseTimeRange(new Date(2026, 7, 18), course({ startSection: 9, duration: 2 }));
    expect([range.start.getHours(), range.start.getMinutes()]).toEqual([19, 0]);
    expect([range.end.getHours(), range.end.getMinutes()]).toEqual([20, 40]);
  });
  it('returns simultaneous courses at the earliest future start', () => {
    const next = findNextCourses(new Date(2026, 7, 18), new Date(2026, 7, 18, 9), [
      course({ id: 'late', startSection: 5 }),
      course({ id: 'a', startSection: 3, name: 'A' }),
      course({ id: 'b', startSection: 3, name: 'B' }),
    ]);
    expect(next.map(({ id }) => id)).toEqual(['a', 'b']);
  });
  it('does not cross timetable boundaries', () => {
    const monday = new Date(2026, 7, 3);
    expect(moveCourseDay(monday, 1, 20, -1).date).toEqual(monday);
  });
  it('creates stable non-index course ids', () => {
    const input = Object.fromEntries(
      Object.entries(course()).filter(([key]) => key !== 'id'),
    ) as Omit<Course, 'id'>;
    expect(stableCourseId('2026-1', '2026-08-18', input)).toBe(
      stableCourseId('2026-1', '2026-08-18', input),
    );
  });
  it('assigns a stable valid color per course name', () => {
    expect(courseColor('高等数学')).toBe(courseColor('高等数学'));
    expect(courseColor('高等数学')).toMatch(/^#[0-9a-f]{6}$/);
    expect(courseColor('大学英语')).toMatch(/^#[0-9a-f]{6}$/);
  });
  it('lays out week slots with placeholders and a fixed total height', () => {
    const slots = buildWeekSlots([
      course({ name: 'A', startSection: 3, duration: 2 }),
      course({ name: 'B', startSection: 7, duration: 1 }),
    ]);
    expect(slots.reduce((sum, slot) => sum + slot.height, 0)).toBe(10);
    expect(slots.filter(({ kind }) => kind === 'course')).toHaveLength(2);
    expect(slots.find(({ course: c }) => c?.name === 'A')?.height).toBe(2);
    expect(slots[0]).toMatchObject({ section: 1, kind: 'empty' });
  });
});
