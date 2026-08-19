import type { FastifyRequest } from 'fastify';

export function requestId(request: FastifyRequest): string {
  return request.id;
}
