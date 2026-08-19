import { Controller, Get } from '@nestjs/common';
import { z } from 'zod';
import {
  AcademicLoginRequestSchema,
  ErrorResponseSchema,
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
          post: { summary: '原子刷新课表', responses: { '200': { description: '新课表快照' } } },
        },
      },
    };
  }
}
