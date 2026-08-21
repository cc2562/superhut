import type { Course } from '@superhut/api-contract';

export const sectionTimes = {
  1: ['08:00', '08:45'],
  2: ['08:55', '09:40'],
  3: ['10:00', '10:45'],
  4: ['10:55', '11:40'],
  5: ['14:00', '14:45'],
  6: ['14:55', '15:40'],
  7: ['16:00', '16:45'],
  8: ['16:55', '17:40'],
  9: ['19:00', '19:45'],
  10: ['19:55', '20:40'],
} as const;

export type DateKey = `${number}-${number}-${number}`;
export function parseStrictDate(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
    ? date
    : null;
}
export function toDateKey(date: Date): DateKey {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}` as DateKey;
}
export function calculateSchoolWeek(firstDayValue: string, now: Date): number | null {
  const firstDay = parseStrictDate(firstDayValue);
  if (!firstDay) return null;
  const weekday = firstDay.getDay() || 7;
  const firstMonday = new Date(firstDay);
  firstMonday.setDate(firstDay.getDate() - weekday + 1);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const days = Math.floor((today.getTime() - firstMonday.getTime()) / 86_400_000) + 1;
  return days < 0 ? 0 : Math.ceil(days / 7);
}
export function sortCourses(courses: readonly Course[]): Course[] {
  return [...courses].sort(
    (a, b) => a.startSection - b.startSection || a.name.localeCompare(b.name),
  );
}
function timeOnDate(date: Date, value: string): Date {
  const parts = value.split(':').map(Number);
  const hour = parts[0] ?? 0;
  const minute = parts[1] ?? 0;
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hour, minute);
}
export function courseTimeRange(day: Date, course: Course): { start: Date; end: Date } {
  const startSection = course.startSection in sectionTimes ? course.startSection : 1;
  const requestedEnd = startSection + course.duration - 1;
  const endSection = requestedEnd in sectionTimes ? requestedEnd : startSection;
  const start = sectionTimes[startSection as keyof typeof sectionTimes][0];
  const end = sectionTimes[endSection as keyof typeof sectionTimes][1];
  return { start: timeOnDate(day, start), end: timeOnDate(day, end) };
}
export function findNextCourses(day: Date, now: Date, courses: readonly Course[]): Course[] {
  if (toDateKey(day) !== toDateKey(now)) return [];
  let nextStart: number | null = null;
  const result: Course[] = [];
  for (const course of sortCourses(courses)) {
    const start = courseTimeRange(day, course).start.getTime();
    if (start <= now.getTime()) continue;
    if (nextStart === null) nextStart = start;
    if (start !== nextStart) break;
    result.push(course);
  }
  return result;
}
export function moveCourseDay(
  day: Date,
  currentWeek: number,
  allWeeks: number,
  delta: -1 | 1,
): { date: Date; week: number } {
  const normalized = new Date(day.getFullYear(), day.getMonth(), day.getDate());
  const weekday = normalized.getDay() || 7;
  if (
    (delta < 0 && currentWeek <= 1 && weekday === 1) ||
    (delta > 0 && currentWeek >= allWeeks && weekday === 7)
  )
    return { date: normalized, week: currentWeek };
  const next = new Date(normalized);
  next.setDate(normalized.getDate() + delta);
  const week = currentWeek + (delta < 0 && weekday === 1 ? -1 : delta > 0 && weekday === 7 ? 1 : 0);
  return { date: next, week };
}
export function stableCourseId(
  semesterId: string,
  date: string,
  course: Omit<Course, 'id'>,
): string {
  const input = [
    semesterId,
    date,
    course.name,
    course.teacherName,
    course.location,
    course.startSection,
    course.duration,
  ].join('|');
  let hash = 0x811c9dc5;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return `course_${(hash >>> 0).toString(16).padStart(8, '0')}`;
}

function hslToHex(hue: number, saturation: number, lightness: number): string {
  const s = saturation / 100;
  const l = lightness / 100;
  const k = (n: number) => (n + hue / 30) % 12;
  const a = s * Math.min(l, 1 - l);
  const channel = (n: number) => l - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  const toHex = (x: number) =>
    Math.round(255 * x)
      .toString(16)
      .padStart(2, '0');
  return `#${toHex(channel(0))}${toHex(channel(8))}${toHex(channel(4))}`;
}

/**
 * 按课程名生成固定颜色（复刻 Flutter 的 hash → HSL 配色思路），同名同色。
 */
export function courseColor(name: string): string {
  let hash = 0;
  for (let index = 0; index < name.length; index += 1) {
    hash = (hash * 31 + name.charCodeAt(index)) | 0;
  }
  return hslToHex(Math.abs(hash) % 360, 55, 55);
}

export interface WeekSlot {
  section: number;
  kind: 'course' | 'empty';
  course?: Course;
  height: number;
  color: string;
}

/**
 * 把某天课程排成「节次块」列表（周视图网格用）：按起始节排序、空白节插占位块、
 * 课程块高度 = 节数，填满 1~10 节（总高恒为 10）。重叠课程按独立块处理（先占先得）。
 */
export function buildWeekSlots(courses: readonly Course[]): WeekSlot[] {
  const sorted = sortCourses(courses);
  const slots: WeekSlot[] = [];
  let current = 1;
  for (const course of sorted) {
    while (current < course.startSection) {
      slots.push({ section: current, kind: 'empty', height: 1, color: '' });
      current += 1;
    }
    slots.push({
      section: course.startSection,
      kind: 'course',
      course,
      height: course.duration,
      color: courseColor(course.name),
    });
    current += course.duration;
  }
  while (current <= 10) {
    slots.push({ section: current, kind: 'empty', height: 1, color: '' });
    current += 1;
  }
  return slots;
}
