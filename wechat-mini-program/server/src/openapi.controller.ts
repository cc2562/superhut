import { Controller, Get } from '@nestjs/common';
import { z } from 'zod';
import {
  AcademicLoginRequestSchema,
  AcademicReloginRequestSchema,
  AdminAnnouncementPageSchema,
  AnnouncementCreateRequestSchema,
  AnnouncementPageSchema,
  AnnouncementPublishRequestSchema,
  AnnouncementSchema,
  AnnouncementSummarySchema,
  AnnouncementUpdateRequestSchema,
  ErrorResponseSchema,
  TimetableRefreshRequestSchema,
  TimetableSchema,
  WechatLoginRequestSchema,
} from '@superhut/api-contract';

@Controller()
export class OpenApiController {
  @Get('openapi.json') document() {
    return {
      openapi: '3.1.0',
      info: { title: 'SuperHUT Mini API', version: '0.1.0' },
      paths: {
        '/v1/auth/wechat/login': {
          post: {
            summary: '建立微信会话',
            requestBody: {
              content: { 'application/json': { schema: z.toJSONSchema(WechatLoginRequestSchema) } },
            },
            responses: { '200': { description: '会话已建立' }, '400': { description: '校验错误' } },
          },
        },
        '/v1/auth/academic/login': {
          post: {
            summary: '绑定教务账号',
            requestBody: {
              content: {
                'application/json': { schema: z.toJSONSchema(AcademicLoginRequestSchema) },
              },
            },
            responses: {
              '200': { description: '绑定成功' },
              '401': {
                description: '凭据错误',
                content: { 'application/json': { schema: z.toJSONSchema(ErrorResponseSchema) } },
              },
            },
          },
        },
        '/v1/auth/academic/relogin': {
          post: {
            summary: '静默自动重登教务账号（豁免验证码）',
            requestBody: {
              content: {
                'application/json': { schema: z.toJSONSchema(AcademicReloginRequestSchema) },
              },
            },
            responses: {
              '200': { description: '重登成功' },
              '401': {
                description: '凭据错误',
                content: { 'application/json': { schema: z.toJSONSchema(ErrorResponseSchema) } },
              },
            },
          },
        },
        '/v1/academic/timetable': {
          get: {
            summary: '读取最后成功课表',
            responses: {
              '200': {
                description: '课表快照',
                content: { 'application/json': { schema: z.toJSONSchema(TimetableSchema) } },
              },
            },
          },
        },
        '/v1/academic/timetable/refresh': {
          post: {
            summary: '原子刷新课表',
            requestBody: {
              content: {
                'application/json': { schema: z.toJSONSchema(TimetableRefreshRequestSchema) },
              },
            },
            responses: { '200': { description: '新课表快照' } },
          },
        },
        '/v1/notifications/summary': {
          get: {
            summary: '读取最新公告与未读数量',
            responses: {
              '200': {
                description: '通知摘要',
                content: {
                  'application/json': { schema: z.toJSONSchema(AnnouncementSummarySchema) },
                },
              },
            },
          },
        },
        '/v1/notifications': {
          get: {
            summary: '分页读取当前用户可见公告',
            responses: {
              '200': {
                description: '通知列表',
                content: { 'application/json': { schema: z.toJSONSchema(AnnouncementPageSchema) } },
              },
            },
          },
        },
        '/v1/notifications/{id}': {
          get: {
            summary: '读取公告详情',
            responses: {
              '200': {
                description: '公告详情',
                content: { 'application/json': { schema: z.toJSONSchema(AnnouncementSchema) } },
              },
              '404': { description: '公告不存在、已撤回或已过期' },
            },
          },
        },
        '/v1/notifications/{id}/read': {
          post: { summary: '幂等标记公告已读', responses: { '200': { description: '已标记' } } },
        },
        '/v1/admin/notifications': {
          get: {
            summary: '管理员分页读取公告',
            responses: {
              '200': {
                description: '管理列表',
                content: {
                  'application/json': { schema: z.toJSONSchema(AdminAnnouncementPageSchema) },
                },
              },
              '403': { description: '无通知管理权限' },
            },
          },
          post: {
            summary: '创建公告草稿',
            requestBody: {
              content: {
                'application/json': { schema: z.toJSONSchema(AnnouncementCreateRequestSchema) },
              },
            },
            responses: { '200': { description: '草稿已创建' }, '403': { description: '无权限' } },
          },
        },
        '/v1/admin/notifications/{id}': {
          put: {
            summary: '编辑公告',
            requestBody: {
              content: {
                'application/json': { schema: z.toJSONSchema(AnnouncementUpdateRequestSchema) },
              },
            },
            responses: { '200': { description: '公告已更新' }, '403': { description: '无权限' } },
          },
        },
        '/v1/admin/notifications/{id}/publish': {
          post: {
            summary: '立即或定时发布公告',
            requestBody: {
              content: {
                'application/json': { schema: z.toJSONSchema(AnnouncementPublishRequestSchema) },
              },
            },
            responses: { '200': { description: '公告已发布或已安排' } },
          },
        },
        '/v1/admin/notifications/{id}/withdraw': {
          post: { summary: '撤回公告', responses: { '200': { description: '公告已撤回' } } },
        },
      },
    };
  }
}
