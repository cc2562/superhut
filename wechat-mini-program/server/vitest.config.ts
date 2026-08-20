import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    // 多个测试文件会各自 bootstrap 一个 NestJS/Fastify 应用，forks 池在 6 个文件时
    // 会因进程 teardown 的 open handle 竞态返回非零退出码；threads 池稳定。
    pool: 'threads',
  },
});
