# 本地开发工作流

## 路径和分支

本 fork 放在 WSL/Linux 文件系统中：

```bash
~/projects/sub2api
```

不建议放在 `/mnt/c/...`。Go 编译、`node_modules` 和 Docker bind mount 在 Linux 文件系统里更稳定。

当前远端和分支：

- `origin`: `https://github.com/Noreply1018/sub2api.git`
- `upstream`: `https://github.com/Wei-Shaw/sub2api.git`
- 本地开发分支：`local-custom`

查看状态：

```bash
git status --short --branch
git remote -v
git branch -vv
```

## Docker 开发模式

开发 compose 会从本地源码构建应用，并启动 PostgreSQL 和 Redis：

```bash
cd ~/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml up --build -d
```

本机使用 `SERVER_PORT=8081`，因为 `127.0.0.1:8080` 已被其他本地容器占用。

访问：

```text
http://127.0.0.1:8081
```

本地管理员账号：

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
