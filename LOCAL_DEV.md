# 本地开发说明

本 fork 已经按 WSL/Linux 文件系统开发方式放在：

```bash
~/projects/sub2api
```

不建议把仓库放在 `/mnt/c/...` 下面。Go 编译、`node_modules` 和 Docker 目录挂载在 Linux 文件系统里更稳定。

## 仓库状态

```bash
git remote -v
git branch --show-current
```

当前基线：

- `origin`: `https://github.com/Noreply1018/sub2api.git`
- `upstream`: `https://github.com/Wei-Shaw/sub2api.git`
- 本地开发分支：`dev/local-custom`

需要同步上游时：

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

从更新后的基线创建功能分支：

```bash
git checkout -b dev/my-feature
```

## Docker 开发模式运行

开发 compose 文件会从本地源码构建应用，并同时启动 PostgreSQL 和 Redis：

```bash
cd ~/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml up --build -d
```

本机 `deploy/.env` 使用 `SERVER_PORT=8081`，因为 `127.0.0.1:8080` 已经被另一个本地容器占用。

浏览器打开：

```text
http://127.0.0.1:8081
```

本地管理员账号：

```text
email: admin@sub2api.local
password: admin123456
```

`deploy/.env`、数据库文件、Redis 文件和运行时数据都已被 git 忽略。

常用 Docker 命令：

```bash
cd ~/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml ps
docker compose -f docker-compose.dev.yml logs -f sub2api
docker compose -f docker-compose.dev.yml restart sub2api
docker compose -f docker-compose.dev.yml down
```

健康检查：

```bash
curl http://127.0.0.1:8081/health
```

预期响应：

```json
{"status":"ok"}
```

## 前端

使用 pnpm，不要使用 npm：

```bash
cd ~/projects/sub2api/frontend
pnpm install --frozen-lockfile
pnpm run build
```

前端构建会把静态产物写入 `backend/internal/web/dist`。

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

## 提交前基线检查

提交普通应用改动前，至少运行：

```bash
cd ~/projects/sub2api/backend
go test -tags=unit ./...

cd ~/projects/sub2api/frontend
pnpm install --frozen-lockfile
pnpm run build
```
