# 后端模块地图

后端是 Go + Gin + Wire + Ent + PostgreSQL + Redis。核心代码在 `backend/`。

## 启动链路

主要入口：

```text
backend/cmd/server/main.go
```

启动流程：

```text
main()
  -> 解析 --setup / --version
  -> setup.NeedsSetup()
  -> setup.AutoSetupFromEnv() 或 setup wizard
  -> runMainServer()
  -> config.LoadForBootstrap()
  -> logger.Init()
  -> initializeApplication(buildInfo)
  -> app.Server.ListenAndServe()
```

`initializeApplication` 来自 Wire 生成代码：

```text
backend/cmd/server/wire.go
backend/cmd/server/wire_gen.go
```

它负责组装配置、数据库、Redis、repository、service、handler、中间件、router 和 HTTP server。

## 配置和初始化

| 职责 | 入口 |
| --- | --- |
| 配置加载 | `backend/internal/config` |
| setup wizard / auto setup | `backend/internal/setup` |
| Ent client / SQL DB | `backend/internal/repository/ent.go`、`db_pool.go` |
| Redis client | `backend/internal/repository/redis.go` |
| 数据库迁移 | `backend/internal/repository/migrations_runner.go`、`backend/migrations/` |
| 日志 | `backend/internal/pkg/logger` |

Docker 开发模式设置了 `AUTO_SETUP=true`，因此首次启动会从环境变量自动初始化管理员、密钥和基础配置。

## HTTP 路由

路由入口：

```text
backend/internal/server/router.go
backend/internal/server/routes/
```

主要分组：

| 路由 | 文件 | 说明 |
| --- | --- | --- |
| `/health` 等通用路由 | `routes/common.go` | 健康检查和基础状态 |
| `/api/v1/auth/*` | `routes/auth.go` | 登录、注册、OAuth、刷新 token |
| `/api/v1/user/*`、`/api/v1/keys` | `routes/user.go` | 用户资料、API Key、usage、订阅等 |
| `/api/v1/admin/*` | `routes/admin.go` | 管理后台接口 |
| `/api/v1/payment/*` | `routes/payment.go` | 支付、订单、webhook |
| `/v1/*`、`/v1beta/*`、`/antigravity/*` | `routes/gateway.go` | 中转网关核心入口 |

全局中间件在 `server/router.go` 里挂载：

- request logger
- access logger
- CORS
- Security headers / CSP
- embedded frontend middleware

网关路由额外挂载：

- 请求体大小限制
- client request id
- ops error logger
- endpoint 归一化
- API Key 鉴权
- 分组绑定检查

## Handler / Service / Repository 分层

```text
handler     HTTP 入参、响应、错误格式、流式响应封装
service     业务逻辑、调度、计费、模型映射、token 处理
repository  Ent/SQL/Redis/HTTP upstream/OAuth client 等外部资源访问
ent/schema  数据模型定义
migrations  数据库迁移脚本
```

注意：项目并不是所有逻辑都严格薄 handler。网关 handler 中包含不少协议适配和 failover 控制，改网关时要同时看 handler 和 service。

## 核心后端模块

| 模块 | 关键位置 | 说明 |
| --- | --- | --- |
| 认证 | `handler/auth_*.go`、`service/auth_*.go` | 登录、注册、OAuth、TOTP、refresh token |
| 用户/API Key | `handler/user_handler.go`、`handler/api_key_handler.go`、`service/api_key_*` | 用户自助功能和 key 管理 |
| 管理后台 | `handler/admin/`、`service/admin_service.go` | 用户、账号、分组、代理、设置等管理功能 |
| 账号 | `service/account*.go`、`repository/account_repo.go` | 上游账号凭证、状态、调度属性 |
| 分组 | `service/channel/group/account` 相关文件 | API Key 到账号池的关键隔离单元 |
| 渠道 | `service/channel_service.go`、`repository/channel_repo.go` | OpenAI channel、模型定价、限制和映射 |
| 网关 | `handler/gateway_*`、`service/gateway_*` | Anthropic/Gemini/Antigravity 兼容路径 |
| OpenAI 网关 | `handler/openai_*`、`service/openai_gateway_*` | OpenAI Responses、Chat、Embeddings、Images |
| 计费和 usage | `service/billing_*`、`service/*record_usage*`、`repository/usage_*` | 扣费、成本计算、usage log |
| 运维监控 | `handler/admin/ops_*`、`service/ops_*`、`repository/ops_*` | ops dashboard、错误日志、实时指标 |
| 支付订阅 | `payment/`、`service/payment_*`、`handler/payment_*` | 充值、订单、套餐、支付服务商 |

## 嵌入前端

前端构建产物输出到：

```text
backend/internal/web/dist
```

Dockerfile 会先构建前端，再把 dist 拷进后端构建上下文，后端用 `embed` 标签把前端静态资源打进二进制。

## 二开风险点

- `backend/cmd/server/wire_gen.go` 是生成文件；改依赖注入应改 `wire.go` 并重新生成。
- `backend/ent/` 多数是生成代码；改模型应从 `backend/ent/schema/*.go` 开始。
- 网关 service 文件很长，改模型映射、调度和 failover 时要先锁定具体平台路径。
- API Key 鉴权结果会影响 gateway context，后续 handler/service 会从 context 取用户、key、group。
- `RunModeSimple` 会跳过部分计费/配额逻辑，调试行为可能和 standard 模式不同。
