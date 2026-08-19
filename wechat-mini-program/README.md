# SuperHUT Mini

“超级包菜”微信原生 TypeScript 小程序与 NestJS/Fastify BFF 的独立 Monorepo。父目录 Flutter
工程保持不变；两端只共享产品定义、数据契约和课程领域规则。

## 目录

- `mini-program/`：微信原生小程序，使用 TDesign 和 `wx.cloud.callContainer`；
- `server/`：BFF、MySQL 8.0 Drizzle Schema 和真实/Fixture 教务适配器；
- `packages/`：API 契约与领域规则；
- `docs/deployment.md`：微信云托管资源、Secret、部署和回滚说明；
- `CHANGELOG.md`：不含个人数据或 Secret 的验证进度。

## 本地开发

需要 Node.js 24 LTS 和 pnpm 10。Fixture 模式不连接学校、微信或 MySQL：

```powershell
pnpm install
$env:APP_MODE='fixture'
pnpm --filter @superhut/server dev
pnpm run ci
```

生产小程序固定调用云环境 `prod-d2gm96mrjfb4565b0` 中的 `superhut-api`，不使用本机 URL、
`wx.login`、`code2Session` 或 AppSecret。微信身份只取自云托管验证后的请求头，BFF 随后签发
自己的短期 access token 和可轮换 refresh token。

## 真实模式

真实模式只依赖 MySQL 8.0。MySQL 必须满足 `lower_case_table_names=0`，所有数据库对象均为
小写；应用启动时在 advisory lock 内执行迁移。用户、教务绑定、session、加密快照、限流计数
和短期查询缓存能够跨容器重启恢复，并使用 MySQL advisory lock 防止重复登录和重复刷新。

Secret 只允许从受保护的本机 `.env` 或微信云托管服务设置读取。学校密码仅用于当次登录请求，
不得进入数据库、日志、Fixture、命令行或 Changelog。阶段 0 的历史验证结果保留在文档中，
旧的 AppSecret/code2Session 验证入口不用于云端部署。

部署操作见 [docs/deployment.md](docs/deployment.md)。备案、类目、隐私指引与校方授权仍是正式
发布门槛，采用云托管不会免除这些要求。
