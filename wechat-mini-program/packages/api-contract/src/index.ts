import { z } from 'zod';

export const errorCodes = [
  'AUTH_REQUIRED',
  'AUTH_ACADEMIC_NOT_BOUND',
  'AUTH_ACADEMIC_INVALID_CREDENTIALS',
  'AUTH_ACADEMIC_EXPIRED',
  'ACADEMIC_UPSTREAM_UNAVAILABLE',
  'ACADEMIC_UPSTREAM_CHANGED',
  'ACADEMIC_RATE_LIMITED',
  'VALIDATION_ERROR',
  'PRIVACY_CONSENT_REQUIRED',
  'INTERNAL_ERROR',
] as const;

export const ErrorCodeSchema = z.enum(errorCodes);
export type ErrorCode = z.infer<typeof ErrorCodeSchema>;

export const MetaSchema = z.object({
  requestId: z.string().min(1),
  fetchedAt: z.string().datetime({ offset: true }).optional(),
  stale: z.boolean().optional(),
});

export const ErrorResponseSchema = z.object({
  error: z.object({ code: ErrorCodeSchema, message: z.string(), requestId: z.string().min(1) }),
});

export const WechatLoginRequestSchema = z
  .object({ privacyConsentVersion: z.string().min(1).max(32) })
  .strict();

export const AcademicLoginRequestSchema = z.object({
  studentId: z
    .string()
    .trim()
    .regex(/^\d{6,20}$/),
  password: z.string().min(1).max(128),
});

export const AcademicBindingSchema = z.object({
  status: z.enum(['active', 'expired', 'unbound']),
  studentIdMasked: z.string().optional(),
  displayName: z.string().optional(),
});

export const CourseSchema = z.object({
  id: z.string().min(1),
  name: z.string(),
  teacherName: z.string(),
  weekDuration: z.string(),
  location: z.string(),
  startSection: z.number().int().min(1).max(10),
  duration: z.number().int().min(1).max(10),
  isExperiment: z.boolean(),
});
export type Course = z.infer<typeof CourseSchema>;

const DateKeySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
export const TimetableSchema = z.object({
  semesterId: z.string(),
  firstWeek: z.number().int().min(1),
  maxWeek: z.number().int().min(1),
  firstDay: DateKeySchema,
  coursesByDate: z.record(DateKeySchema, z.array(CourseSchema)),
});
export type Timetable = z.infer<typeof TimetableSchema>;

export const SemesterSchema = z.object({ id: z.string(), name: z.string(), current: z.boolean() });
export const ScoreSchema = z.object({
  courseName: z.string(),
  courseAttribute: z.string(),
  courseNature: z.string(),
  examName: z.string(),
  examNature: z.string(),
  score: z.string(),
  passed: z.boolean(),
  gradePoint: z.number().nullable(),
  credit: z.number().nullable(),
});
export const ExamSchema = z.object({
  courseName: z.string(),
  date: z.string(),
  time: z.string(),
  location: z.string(),
  seat: z.string().optional(),
});
export const BuildingSchema = z.object({ id: z.string(), name: z.string() });
export const FreeRoomSchema = z.object({ id: z.string(), name: z.string() });
export const SessionSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  expiresIn: z.number().int().positive(),
  academicBinding: AcademicBindingSchema,
});

export type WechatLoginRequest = z.infer<typeof WechatLoginRequestSchema>;
export type AcademicLoginRequest = z.infer<typeof AcademicLoginRequestSchema>;
export interface SuccessResponse<T> {
  data: T;
  meta: z.infer<typeof MetaSchema>;
}
export function successResponse<T>(data: T, requestId: string): SuccessResponse<T> {
  return { data, meta: { requestId } };
}
