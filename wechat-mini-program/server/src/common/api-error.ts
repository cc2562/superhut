import type { ErrorCode } from '@superhut/api-contract';

export class ApiError extends Error {
  constructor(
    public readonly code: ErrorCode,
    public readonly status: number,
    message: string,
  ) {
    super(message);
  }
}
