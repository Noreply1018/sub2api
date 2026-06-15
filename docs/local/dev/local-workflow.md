# 本地开发工作流

## 路径和分支

本 fork 放在 WSL/Linux 文件系统中：

```bash
~/projects/sub2api
```

不建议放在 `/mnt/c/...`。Go 编译、`node_modules` 和 Docker bind mount 在 Linux 文件系统里更稳定。

当前远端和分支：

- `origin`: `git@github.com:Noreply1018/sub2api-local.git`
- `upstream`: `https://github.com/Wei-Shaw/sub2api.git`
- 本地开发分支：`local-custom`

查看状态：

```bash
git status --short --branch
git remote -v
git branch -vv
```

## 分支习惯和提交类型

`local-custom` 是本 fork 的默认本地工作分支，用来承接上游同步、本地文档和后续二开改动。当前按个人二开方式维护，默认直接在 `local-custom` 上修改、验证、提交并推送。

开始改动前先确认分支和远端状态：

```bash
cd ~/projects/sub2api
git checkout local-custom
git pull --ff-only origin local-custom
```

改完后检查、提交并推送：

```bash
git status --short
git add <files>
git commit -m "<type>: <summary>"
git push origin local-custom
```

`<type>` 是提交信息里的改动类型，不是必须开的分支名：

- `feat`：feature，新增或调整功能。
- `fix`：修复 bug。
- `docs`：只改文档。
- `chore`：工具、配置或流程维护。

示例：

```bash
git commit -m "docs: update local workflow"
git commit -m "fix: handle empty token"
git commit -m "feat: add local account note"
```

只有在用户明确要求，或者改动风险较高且已经先确认时，才额外创建短分支：

```bash
git checkout -b feat/<topic>
```

## 两套本地运行环境

当前本机保留两套环境：

| 用途 | 路径 | 访问地址 | Docker Desktop 组名 | 说明 |
| --- | --- | --- | --- | --- |
| 日常使用版 | `~/apps/sub2api` | `http://127.0.0.1:8080` | `sub2api` | 使用发布镜像和独立数据卷，保持稳定可用 |
| 开发调试版 | `~/projects/sub2api` | `http://127.0.0.1:8081` | `deploy` | 从本地源码构建，适合二次开发和调试 |

这样做的目的是让日常使用不受开发改动影响。开发版可以随时重建、改代码、清数据；日常版只在需要升级或迁移时处理。

## 日常使用版

日常使用版位于：

```bash
~/apps/sub2api
```

它使用 `docker-compose.yml`、`.env`、`postgres_data/`、`redis_data/` 和 `data/` 组成一个独立运行环境。这个目录不属于仓库，里面的 `.env` 包含本地密钥，不应提交到 git。

访问：

```text
http://127.0.0.1:8080
```

本地管理员账号：

```text
email: admin@sub2api.local
password: admin123456
```

健康检查：

```bash
curl http://127.0.0.1:8080/health
```

预期响应：

```json
{"status":"ok"}
```

常用命令：

```bash
cd ~/apps/sub2api
docker compose ps
docker compose logs -f sub2api
docker compose restart sub2api
docker compose down
```

也可以在 Docker Desktop GUI 中操作：找到名为 `sub2api` 的 Compose 组，点击启动或停止整个组。不要只启动单个应用容器，因为它还依赖 PostgreSQL 和 Redis。

## Docker 开发模式

开发 compose 会从本地源码构建应用，并启动 PostgreSQL 和 Redis：

```bash
cd ~/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml up --build -d
```

本机开发版使用 `SERVER_PORT=8081`，避免和日常使用版的 `127.0.0.1:8080` 冲突。

访问：

```text
http://127.0.0.1:8081
```

开发版使用同一组本地管理员账号：

```text
email: admin@sub2api.local
password: admin123456
```

健康检查：

```bash
curl http://127.0.0.1:8081/health
```

预期响应：

```json
{"status":"ok"}
```

常用命令：

```bash
cd ~/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml logs -f sub2api
docker compose -f docker-compose.dev.yml restart sub2api
docker compose -f docker-compose.dev.yml down
```

`deploy/.env`、数据库文件、Redis 文件、运行数据和前端依赖目录都被 git 忽略。

## 前端

前端必须使用 pnpm：

```bash
cd ~/projects/sub2api/frontend
pnpm install --frozen-lockfile
pnpm run build
```

前端构建会把静态产物写入：

```text
backend/internal/web/dist
```

## 后端

当前上游 `backend/go.mod` 要求 Go `1.26.3`。如果本机 `GOTOOLCHAIN=auto`，Go 可以自动下载所需 toolchain。

```bash
cd ~/projects/sub2api/backend
go test -tags=unit ./...
```

修改 Ent schema 后：

```bash
cd ~/projects/sub2api/backend
go generate ./ent
```

schema 改动和生成后的 Ent 代码需要一起提交。

## 同步上游

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

再从更新后的 `main` 创建新分支，或把当前二开分支 rebase/merge 到最新基线。

## 提交规则

提交前至少运行：

```bash
cd ~/projects/sub2api/backend
go test -tags=unit ./...

cd ~/projects/sub2api/frontend
pnpm install --frozen-lockfile
pnpm run build
```

仓库规则要求：当改动来自 Codex 自己时，完成验证后应自觉执行 git 提交；不要提交用户已有或无关改动。
