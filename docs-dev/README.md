# 二次开发文档入口

这组文档用于帮助后续二次开发快速定位模块、理解请求流和确认改动入口。它不是官方用户手册，而是本 fork 的开发地图。

## 阅读顺序

1. [local-workflow.md](./local-workflow.md)：本地运行、验证、分支和提交流程。
2. [backend-map.md](./backend-map.md)：后端启动链路、依赖注入、路由和模块职责。
3. [frontend-map.md](./frontend-map.md)：前端 API、store、router、页面结构。
4. [request-flow.md](./request-flow.md)：网关请求从客户端到上游再到 usage 记录的主链路。
5. [data-models.md](./data-models.md)：核心数据对象和它们之间的关系。
6. [data-safety.md](./data-safety.md)：本地正式版/调试版的数据保护、备份、校验和恢复流程。

## 当前本地基线

- 仓库路径：`~/projects/sub2api`
- 本地分支：`local-custom`
- 远端分支：`origin/local-custom`
- 日常使用版：`http://127.0.0.1:8080`，路径 `~/apps/sub2api`，Docker Desktop 组名 `sub2api`
- 开发调试版：`http://127.0.0.1:8081`，路径 `~/projects/sub2api`，Docker Desktop 组名 `deploy`
- 开发 compose：`deploy/docker-compose.dev.yml`

## 常见二开入口

| 目标 | 优先查看 |
| --- | --- |
| 改登录、注册、OAuth | `backend/internal/handler/auth_*.go`、`backend/internal/service/auth_*.go`、`frontend/src/api/auth.ts`、`frontend/src/views/auth/` |
| 改用户 API Key | `backend/internal/handler/api_key_handler.go`、`backend/internal/service/api_key_*.go`、`frontend/src/api/keys.ts`、`frontend/src/views/user/KeysView.vue` |
| 改账号、分组、渠道 | `backend/internal/handler/admin/*account*`、`*group*`、`*channel*`，以及对应 service/repository |
| 改网关转发或模型映射 | `backend/internal/server/routes/gateway.go`、`backend/internal/handler/gateway_*`、`backend/internal/service/gateway_*`、`backend/internal/service/openai_gateway_*` |
| 改计费、配额、usage | `backend/internal/service/billing_*`、`usage_*`、`user_platform_quota_*`、`backend/ent/schema/usage_log.go` |
| 改前端管理页 | `frontend/src/views/admin/`、`frontend/src/api/admin/`、`frontend/src/components/admin/` |

## 维护原则

- 文档按专题拆分，避免所有内容堆进一个大文件。
- 只记录对二开有用的结构、入口和约束，不复制完整源码。
- 代码结构变化后，同步更新对应专题文档。
