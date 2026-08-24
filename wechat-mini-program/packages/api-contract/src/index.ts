import { z } from 'zod';

export const errorCodes = [
  'AUTH_REQUIRED',
  'AUTH_ACADEMIC_NOT_BOUND',
  'AUTH_ACADEMIC_INVALID_CREDENTIALS',
  'AUTH_ACADEMIC_EXPIRED',
  'ACADEMIC_UPSTREAM_UNAVAILABLE',
  'ACADEMIC_UPSTREAM_CHANGED',
  'ACADEMIC_RATE_LIMITED',
  'CAPTCHA_REQUIRED',
  'CAPTCHA_VERIFY_FAILED',
  'CAPTCHA_SERVICE_UNAVAILABLE',
  'VALIDATION_ERROR',
  'PRIVACY_CONSENT_REQUIRED',
  'AUTH_FORBIDDEN',
  'RESOURCE_NOT_FOUND',
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
  captchaVerifyParam: z.string().min(1).max(8192).optional(),
});

export const AcademicReloginRequestSchema = z.object({
  studentId: z
    .string()
    .trim()
    .regex(/^\d{6,20}$/),
  password: z.string().min(1).max(128),
});

export const TimetableRefreshRequestSchema = z
  .object({
    captchaVerifyParam: z.string().min(1).max(8192).optional(),
    semesterId: z.string().max(64).optional(),
  })
  .strict();

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

export const AcademicLoginResponseSchema = z.object({
  academicBinding: AcademicBindingSchema,
  timetable: TimetableSchema.nullable(),
  timetableFetchedAt: z.string().datetime({ offset: true }).nullable(),
});

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
export const ScoreSummarySchema = z.object({
  earnedCredits: z.string(),
  totalGradePoints: z.string(),
  averageGradePoint: z.string(),
});
export const ScoresResponseSchema = z.object({
  scores: z.array(ScoreSchema),
  summary: ScoreSummarySchema,
});
export const ExamSchema = z.object({
  courseName: z.string(),
  date: z.string(),
  time: z.string(),
  location: z.string(),
  seat: z.string().optional(),
});
export const BuildingSchema = z.object({ id: z.string(), name: z.string() });
export const FreeRoomSchema = z.object({
  id: z.string(),
  name: z.string(),
  seatNumber: z.string(),
  occupied: z.array(z.string()),
});

export const EvaluationBatchSchema = z.object({
  id: z.string(),
  name: z.string(),
  category: z.string(),
  semesterName: z.string(),
  pj01id: z.string(),
  pj05id: z.string(),
});
export const EvaluationItemSchema = z.object({
  courseId: z.string(),
  courseName: z.string(),
  courseNumber: z.string(),
  teacherName: z.string(),
  evaluationCategoriesId: z.string(),
  teacherId: z.string(),
  noticeId: z.string(),
  submitted: z.boolean(),
});
export const EvaluationOptionSchema = z.object({
  id: z.string(),
  name: z.string(),
  score: z.number(),
});
export const EvaluationQuestionSchema = z.object({
  id: z.string(),
  name: z.string(),
  options: z.array(EvaluationOptionSchema),
});
export const EvaluationTargetSchema = z.object({
  questionId: z.string(),
  optionId: z.string(),
});
export const EvaluationSubmitRequestSchema = z
  .object({
    batchId: z.string(),
    courseId: z.string(),
    evaluationCategoriesId: z.string(),
    teacherId: z.string(),
    noticeId: z.string(),
    target: z.array(EvaluationTargetSchema).min(1),
  })
  .strict();
export const EvaluationItemRequestSchema = z
  .object({
    batchId: z.string(),
    courseId: z.string(),
    evaluationCategoriesId: z.string(),
    teacherId: z.string(),
    noticeId: z.string(),
  })
  .strict();
export const EvaluationBatchRequestSchema = z
  .object({
    pj01id: z.string(),
    batchId: z.string(),
    pj05id: z.string(),
  })
  .strict();
export const EvaluationBatchResultSchema = z.object({
  total: z.number().int(),
  succeeded: z.number().int(),
  failed: z.number().int(),
  results: z.array(
    z.object({
      courseId: z.string(),
      courseName: z.string(),
      success: z.boolean(),
      message: z.string().optional(),
    }),
  ),
});

export const SessionSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  expiresIn: z.number().int().positive(),
  academicBinding: AcademicBindingSchema,
});

export const AnnouncementStatusSchema = z.enum(['draft', 'scheduled', 'published', 'withdrawn']);
export const AnnouncementActionPathSchema = z.enum([
  '/pages/timetable/index',
  '/pages/scores/index',
  '/pages/exams/index',
  '/pages/rooms/index',
  '/pages/evaluation/batches/index',
  '/pages/agreement/index',
]);
export const AnnouncementSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  summary: z.string(),
  content: z.string(),
  actionPath: AnnouncementActionPathSchema.nullable(),
  publishAt: z.string().datetime({ offset: true }),
  expiresAt: z.string().datetime({ offset: true }).nullable(),
  updatedAt: z.string().datetime({ offset: true }),
  read: z.boolean(),
});
export const AnnouncementSummarySchema = z.object({
  latest: AnnouncementSchema.nullable(),
  unreadCount: z.number().int().nonnegative(),
});
export const AnnouncementPageSchema = z.object({
  items: z.array(AnnouncementSchema),
  nextCursor: z.string().nullable(),
});
export const AdminAnnouncementSchema = AnnouncementSchema.omit({ read: true }).extend({
  status: AnnouncementStatusSchema,
  publishAt: z.string().datetime({ offset: true }).nullable(),
  createdAt: z.string().datetime({ offset: true }),
});
export const AdminAnnouncementPageSchema = z.object({
  items: z.array(AdminAnnouncementSchema),
  nextCursor: z.string().nullable(),
});
const nullableDateTime = z.string().datetime({ offset: true }).nullable();
export const AnnouncementCreateRequestSchema = z
  .object({
    title: z.string().trim().min(1).max(80),
    summary: z.string().trim().min(1).max(160),
    content: z.string().trim().min(1).max(10_000),
    actionPath: AnnouncementActionPathSchema.nullable().default(null),
    expiresAt: nullableDateTime.default(null),
  })
  .strict();
export const AnnouncementUpdateRequestSchema = AnnouncementCreateRequestSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'at least one field is required',
);
export const AnnouncementPublishRequestSchema = z
  .object({
    publishAt: z.string().datetime({ offset: true }),
    expiresAt: nullableDateTime.default(null),
  })
  .strict()
  .refine(
    ({ publishAt, expiresAt }) => !expiresAt || Date.parse(expiresAt) > Date.parse(publishAt),
    'expiresAt must be later than publishAt',
  );

export type WechatLoginRequest = z.infer<typeof WechatLoginRequestSchema>;
export type AcademicLoginRequest = z.infer<typeof AcademicLoginRequestSchema>;
export type AcademicReloginRequest = z.infer<typeof AcademicReloginRequestSchema>;
export type TimetableRefreshRequest = z.infer<typeof TimetableRefreshRequestSchema>;
export type AcademicLoginResponse = z.infer<typeof AcademicLoginResponseSchema>;
export type EvaluationBatch = z.infer<typeof EvaluationBatchSchema>;
export type EvaluationItem = z.infer<typeof EvaluationItemSchema>;
export type EvaluationOption = z.infer<typeof EvaluationOptionSchema>;
export type EvaluationQuestion = z.infer<typeof EvaluationQuestionSchema>;
export type EvaluationTarget = z.infer<typeof EvaluationTargetSchema>;
export type EvaluationSubmitRequest = z.infer<typeof EvaluationSubmitRequestSchema>;
export type EvaluationItemRequest = z.infer<typeof EvaluationItemRequestSchema>;
export type EvaluationBatchRequest = z.infer<typeof EvaluationBatchRequestSchema>;
export type EvaluationBatchResult = z.infer<typeof EvaluationBatchResultSchema>;
export type ScoreSummary = z.infer<typeof ScoreSummarySchema>;
export type ScoresResponse = z.infer<typeof ScoresResponseSchema>;
export type FreeRoom = z.infer<typeof FreeRoomSchema>;
export type AnnouncementStatus = z.infer<typeof AnnouncementStatusSchema>;
export type AnnouncementActionPath = z.infer<typeof AnnouncementActionPathSchema>;
export type Announcement = z.infer<typeof AnnouncementSchema>;
export type AnnouncementSummary = z.infer<typeof AnnouncementSummarySchema>;
export type AnnouncementPage = z.infer<typeof AnnouncementPageSchema>;
export type AdminAnnouncement = z.infer<typeof AdminAnnouncementSchema>;
export type AdminAnnouncementPage = z.infer<typeof AdminAnnouncementPageSchema>;
export type AnnouncementCreateRequest = z.infer<typeof AnnouncementCreateRequestSchema>;
export type AnnouncementUpdateRequest = z.infer<typeof AnnouncementUpdateRequestSchema>;
export type AnnouncementPublishRequest = z.infer<typeof AnnouncementPublishRequestSchema>;
export interface SuccessResponse<T> {
  data: T;
  meta: z.infer<typeof MetaSchema>;
}
export function successResponse<T>(data: T, requestId: string): SuccessResponse<T> {
  return { data, meta: { requestId } };
}
