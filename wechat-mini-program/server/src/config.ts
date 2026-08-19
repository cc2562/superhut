import { z } from 'zod';

const EnvironmentSchema = z.object({
  APP_MODE: z.enum(['fixture', 'real']).default('fixture'),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  WECHAT_CLOUD_ENV_ID: z.string().default('fixture-env-id'),
  MYSQL_HOST: z.string().default(''),
  MYSQL_PORT: z.coerce.number().int().min(1).max(65_535).default(3306),
  MYSQL_DATABASE: z.string().default('superhut'),
  MYSQL_USER: z.string().default(''),
  MYSQL_PASSWORD: z.string().default(''),
  SESSION_SIGNING_KEY: z.string().min(32).default('fixture-session-key-not-for-production'),
  FIELD_ENCRYPTION_KEY_CURRENT: z.string().default(''),
  FIELD_ENCRYPTION_KEY_VERSION: z.string().default('v1'),
  HMAC_INDEX_KEY: z.string().min(32).default('fixture-hmac-index-key-not-production'),
  HUT_ACADEMIC_BASE_URL: z.string().url().default('https://jwxtsj.hut.edu.cn'),
  ACADEMIC_PASSWORD_KEY: z.string().default(''),
  ALLOWED_MINIPROGRAM_APP_ID: z.string().default('fixture-app-id'),
});

export type Environment = z.infer<typeof EnvironmentSchema>;
let cached: Environment | undefined;

export function environment(): Environment {
  cached ??= EnvironmentSchema.parse(process.env);
  if (cached.NODE_ENV === 'production' && cached.APP_MODE !== 'real') {
    throw new Error('production requires APP_MODE=real');
  }
  if (cached.APP_MODE === 'real') {
    const required = [
      'WECHAT_CLOUD_ENV_ID',
      'MYSQL_HOST',
      'MYSQL_USER',
      'MYSQL_PASSWORD',
      'SESSION_SIGNING_KEY',
      'FIELD_ENCRYPTION_KEY_CURRENT',
      'HMAC_INDEX_KEY',
      'ACADEMIC_PASSWORD_KEY',
      'ALLOWED_MINIPROGRAM_APP_ID',
    ] as const;
    for (const key of required)
      if (!cached[key]) throw new Error(`${key} is required in real mode`);
    if (Buffer.from(cached.FIELD_ENCRYPTION_KEY_CURRENT, 'base64').length !== 32) {
      throw new Error('FIELD_ENCRYPTION_KEY_CURRENT must decode to exactly 32 bytes');
    }
    if (
      cached.WECHAT_CLOUD_ENV_ID === 'fixture-env-id' ||
      cached.ALLOWED_MINIPROGRAM_APP_ID === 'fixture-app-id' ||
      cached.SESSION_SIGNING_KEY.includes('fixture') ||
      cached.HMAC_INDEX_KEY.includes('fixture')
    ) {
      throw new Error('fixture configuration is forbidden in real mode');
    }
  }
  return cached;
}
