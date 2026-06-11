# 数据安全与恢复

本文记录本地两套 Sub2API 部署的数据落点、启动保护、备份、校验和恢复流程。

## 数据落点

正式版：

- 服务地址：`http://127.0.0.1:8080`
- 运行目录：`/home/lh/apps/sub2api`
- PostgreSQL：`/home/lh/apps/sub2api/postgres_data`
- Redis：`/home/lh/apps/sub2api/redis_data`
- 应用配置：`/home/lh/apps/sub2api/data`

调试版：

- 服务地址：`http://127.0.0.1:8081`
- 运行目录：`/home/lh/projects/sub2api/deploy`
- PostgreSQL：`/home/lh/projects/sub2api/deploy/postgres_data`
- Redis：`/home/lh/projects/sub2api/deploy/redis_data`
- 应用配置：`/home/lh/projects/sub2api/deploy/data`

PostgreSQL 是主数据源。Redis 主要保存缓存和短期状态，不能替代 PostgreSQL 备份。

## 启动保护

PostgreSQL 容器使用 `deploy/scripts/postgres-guard-entrypoint.sh` 包装官方 entrypoint。保护逻辑：

- `PG_VERSION` 存在：认为数据库目录有效，允许启动。
- `PG_VERSION` 缺失且 `.postgres-initialized` 存在：认为已初始化部署的数据目录异常，拒绝启动。
- `PG_VERSION` 缺失且 `.postgres-initialized` 缺失：允许首次初始化。
- 只有明确设置 `ALLOW_EMPTY_DATABASE_INIT=true` 时，才允许对已有哨兵的空目录初始化。

哨兵文件位置：

- 正式版：`/home/lh/apps/sub2api/data/.postgres-initialized`
- 调试版：`/home/lh/projects/sub2api/deploy/data/.postgres-initialized`

如果 guard 拦截启动，不要直接设置 `ALLOW_EMPTY_DATABASE_INIT=true`。应先检查挂载、路径、权限和备份，确认是否能找回原数据目录。

## 备份

手动备份正式版：

```bash
cd /home/lh/projects/sub2api
tools/backup_db.sh prod
```

手动备份调试版：

```bash
cd /home/lh/projects/sub2api
tools/backup_db.sh dev
```

备份默认写入：

```text
/home/lh/backups/sub2api-auto/<prod|dev>/<YYYYMMDD-HHMMSS>/
```

每个备份目录包含：

- `database.dump`：PostgreSQL custom-format dump。
- `app-config.tgz`：`.env`、compose 文件和 `data/` 配置快照。
- `table-counts.txt`：关键表计数。
- `SHA256SUMS`：备份文件校验和。
- `manifest.txt`：容器和镜像信息。

正式版已配置 user systemd timer：

```bash
systemctl --user list-timers sub2api-prod-backup.timer --no-pager
```

默认每天凌晨运行一次正式版备份。

## 校验

轻量校验：

```bash
tools/verify_db_backup.sh /home/lh/backups/sub2api-auto/prod/<timestamp>
```

深度校验：

```bash
tools/verify_db_backup.sh /home/lh/backups/sub2api-auto/prod/<timestamp> --deep
```

深度校验会临时启动一个 PostgreSQL 18 容器，真实恢复 dump，并查询 `users`、`accounts`、`api_keys`、`usage_logs` 表计数。临时容器会在校验结束后删除。

日常安全审计：

```bash
tools/audit_data_safety.sh
```

审计内容包括：

- `PG_VERSION` 是否存在。
- guard 哨兵是否存在。
- compose 是否启用 guard。
- 关键表计数。
- 最近备份目录。

## 恢复

恢复会覆盖目标数据库。恢复前必须先备份当前状态：

```bash
tools/backup_db.sh prod
```

恢复正式版：

```bash
tools/restore_db.sh prod /home/lh/backups/sub2api-auto/prod/<timestamp> --confirm-prod-restore
```

恢复调试版：

```bash
tools/restore_db.sh dev /home/lh/backups/sub2api-auto/dev/<timestamp> --confirm-dev-restore
```

恢复后执行：

```bash
curl http://127.0.0.1:8080/health
tools/audit_data_safety.sh
```

## 事故处理

如果 Postgres 容器无法启动且日志出现 `Refusing to initialize an empty database`：

1. 不要删除 `.postgres-initialized`。
2. 不要设置 `ALLOW_EMPTY_DATABASE_INIT=true`。
3. 检查 `postgres_data` 是否为空、权限是否异常、路径是否被替换。
4. 查找是否存在旧数据目录或备份。
5. 选择最近通过校验的备份恢复。

只有确认要放弃旧数据并重新建库时，才可以临时设置 `ALLOW_EMPTY_DATABASE_INIT=true`。
