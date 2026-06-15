# sub2api-local

`sub2api-local` 是基于 [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api) 的二次开发版本，不是上游官方项目。

本仓库保留上游 Sub2API 的核心能力，并在 `local-custom` 分支上维护本地部署、调试、数据保护和后续定制改动。公开使用本仓库时，请优先阅读本 README 和 `docs/local/` 下的文档；上游原始说明仅作为来源参考和兼容性参考。

## 文档入口

| 入口 | 说明 |
| --- | --- |
| [docs/local/README.md](./docs/local/README.md) | `sub2api-local` 的本地文档总入口 |
| [docs/local/dev/README.md](./docs/local/dev/README.md) | 二次开发模块地图、请求流、数据模型和本地工作流 |
| [docs/local/dev/local-workflow.md](./docs/local/dev/local-workflow.md) | 本地运行、验证、分支和提交流程 |
| [docs/local/dev/data-safety.md](./docs/local/dev/data-safety.md) | 8080 正式版与 8081 调试版的数据保护流程 |
| [docs/upstream/README.md](./docs/upstream/README.md) | 上游用户文档与部署说明的索引入口 |
| [docs/upstream/project/README.md](./docs/upstream/project/README.md) | 上游英文 README 参考 |
| [docs/upstream/project/README_CN.md](./docs/upstream/project/README_CN.md) | 上游中文 README 参考 |
| [docs/upstream/project/README_JA.md](./docs/upstream/project/README_JA.md) | 上游日文 README 参考 |

## 与上游的关系

- 上游仓库：`Wei-Shaw/sub2api`
- 本 fork 远端：`origin`
- 上游远端：`upstream`
- 本地二开主线：`local-custom`
- 本项目自称：`sub2api-local`

本仓库不会把上游 README 的项目定位当作当前 fork 的对外定位。上游文档已移动到 `docs/upstream/`，用于保留来源、对照官方功能和辅助后续同步。

## 本地运行基线

当前本机保留两套环境：

| 用途 | 路径 | 地址 | Docker Desktop 组名 |
| --- | --- | --- | --- |
| 日常使用版 | `~/apps/sub2api` | `http://127.0.0.1:8080` | `sub2api` |
| 开发调试版 | `~/projects/sub2api` | `http://127.0.0.1:8081` | `deploy` |

健康检查：

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8081/health
```

默认本地管理员账号：

```text
账号：admin@sub2api.local
密码：admin123456
```

开发调试版启动：

```bash
cd ~/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml up --build -d
```

更完整的运行、验证、提交和上游同步流程见 [docs/local/dev/local-workflow.md](./docs/local/dev/local-workflow.md)。

## 目录约定

- `docs/local/`：本 fork 当前维护的文档。
- `docs/local/dev/`：二次开发、模块地图、本地部署和数据安全说明。
- `docs/upstream/`：从上游继承的参考文档，不代表本 fork 当前推荐部署方式。
- `deploy/`：实际部署和开发 compose 文件仍保留在原位置，便于运行环境继续使用。

## License

本项目遵循上游项目的许可证，见 [LICENSE](./LICENSE)。上游作者和项目来源保留在 `docs/upstream/` 及提交历史中。
