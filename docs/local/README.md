# sub2api-local 本地文档

这里存放 `sub2api-local` 当前维护的文档。它们描述本 fork 的运行方式、开发流程、数据保护和模块结构，优先级高于 `docs/upstream/` 中的上游参考文档。

## 常用入口

- [二次开发文档入口](./dev/README.md)
- [本地开发工作流](./dev/local-workflow.md)
- [后端模块地图](./dev/backend-map.md)
- [前端模块地图](./dev/frontend-map.md)
- [网关请求流](./dev/request-flow.md)
- [核心数据模型](./dev/data-models.md)
- [数据安全流程](./dev/data-safety.md)
- [待办记录](./dev/backlog.md)

## 当前本地基线

- 仓库路径：`~/projects/sub2api`
- 项目自称：`sub2api-local`
- 本地分支：`local-custom`
- 远端分支：`origin/local-custom`
- 日常使用版：`http://127.0.0.1:8080`，路径 `~/apps/sub2api`，Docker Desktop 组名 `sub2api`
- 开发调试版：`http://127.0.0.1:8081`，路径 `~/projects/sub2api`，Docker Desktop 组名 `deploy`
- 开发 compose：`deploy/docker-compose.dev.yml`

## 维护原则

- 新增本地说明优先放在 `docs/local/`。
- 只有用于保留上游来源或对照官方说明的内容放在 `docs/upstream/`。
- 文档中的项目称呼统一使用 `sub2api-local`；提到 `Sub2API` 时应明确是上游或原项目语境。
