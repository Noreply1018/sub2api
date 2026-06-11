#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法:
  tools/restore_db.sh prod /path/to/backup-dir --confirm-prod-restore
  tools/restore_db.sh dev /path/to/backup-dir --confirm-dev-restore

说明:
  恢复会覆盖目标环境数据库。执行前请先运行 tools/backup_db.sh 保存现状。
USAGE
}

env_name="${1:-}"
backup_dir="${2:-}"
confirm="${3:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$env_name" in
  prod)
    pg_container="sub2api-postgres"
    app_container="sub2api"
    expected_confirm="--confirm-prod-restore"
    ;;
  dev)
    pg_container="sub2api-postgres-dev"
    app_container="sub2api-dev"
    expected_confirm="--confirm-dev-restore"
    ;;
  -h|--help|"")
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ "$confirm" != "$expected_confirm" ]; then
  usage >&2
  printf '缺少确认参数: %s\n' "$expected_confirm" >&2
  exit 2
fi

dump="$backup_dir/database.dump"
[ -f "$dump" ] || {
  printf '找不到备份文件: %s\n' "$dump" >&2
  exit 2
}

"$script_dir/verify_db_backup.sh" "$backup_dir" >/dev/null

tmp_dump="/tmp/sub2api-restore-$(date +%Y%m%d-%H%M%S).dump"
docker cp "$dump" "$pg_container:$tmp_dump"
app_was_running="false"
if [ "$(docker inspect "$app_container" --format '{{.State.Running}}' 2>/dev/null || true)" = "true" ]; then
  app_was_running="true"
  docker stop "$app_container" >/dev/null
fi

cleanup() {
  docker exec "$pg_container" rm -f "$tmp_dump" >/dev/null 2>&1 || true
  if [ "$app_was_running" = "true" ]; then
    docker start "$app_container" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

docker exec "$pg_container" sh -eu -c "dropdb -U sub2api --if-exists sub2api && createdb -U sub2api sub2api && pg_restore -U sub2api -d sub2api --clean --if-exists '$tmp_dump'"
docker exec "$pg_container" rm -f "$tmp_dump" >/dev/null
trap - EXIT
if [ "$app_was_running" = "true" ]; then
  docker start "$app_container" >/dev/null
fi
printf '恢复完成: %s <- %s\n' "$env_name" "$backup_dir"
