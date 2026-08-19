# 微信云托管部署

## 固定资源

- 环境：`prod-d2gm96mrjfb4565b0`（上海）
- 服务：`superhut-api`
- 容器端口：`3000`
- 调用方式：仅允许直属小程序通过 `wx.cloud.callContainer` 调用，关闭公网访问
- 运行策略：最低可用规格，允许缩容到零

在云托管控制台创建 MySQL 8.0。MySQL 必须选择表名大小写敏感；连接后执行
`SELECT @@lower_case_table_names`，只有结果为 `0` 才允许启动。数据库名固定为 `superhut`，
应用和迁移中的标识符全部使用小写。

## Secret 与环境变量

在控制台服务设置中注入 `.env.example` 列出的真实模式变量。以下值属于 Secret，只能在
控制台输入：`MYSQL_PASSWORD`、`SESSION_SIGNING_KEY`、
`FIELD_ENCRYPTION_KEY_CURRENT`、`HMAC_INDEX_KEY`、`ACADEMIC_PASSWORD_KEY`。

不得把 Secret 放进仓库、CLI 参数、部署备注、构建日志或 Changelog。微信身份由云托管可信
请求头提供，生产环境不配置 `WECHAT_APP_SECRET`。

## 首次发布

```bash
pnpm install --frozen-lockfile
pnpm run ci
docker build -t superhut-api:local .
pnpm cloud:services
pnpm cloud:deploy
```

容器启动时先使用 MySQL advisory lock 执行 Drizzle 迁移；迁移或大小写敏感检查失败时服务不
启动。首版没有旧流量，采用全量发布。发布后从开发者工具通过 `callContainer` 检查
`/health/live` 与 `/health/ready`，不得依赖默认公网域名进行生产验证。

## 后续发布与回滚

后续版本先运行完整 CI 和镜像构建，再将发布类型改为 `GRAY` 灰度验证。确认健康检查、错误率
和关键业务闭环后再全量。回滚命令：

```bash
wxcloud run:rollback --envId prod-d2gm96mrjfb4565b0 --serviceName superhut-api --version <版本号>
```

数据库变更采用向后兼容的 expand/contract 方式，破坏性字段删除必须跨两个版本完成。
