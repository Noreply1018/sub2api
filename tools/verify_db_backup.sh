#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法:
  tools/verify_db_backup.sh /path/to/backup-dir
  tools/verify_db_backup.sh /path/to/backup-dir --deep

要求备份目录包含:
  database.dump
  SHA256SUMS
USAGE
}

backup_dir="${1:-}"
mode="${2:-}"
if [ -z "$backup_dir" ] || [ "$backup_dir" = "-h" ] || [ "$backup_dir" = "--help" ]; then
  usage
  exit 0
fi
if [ -n "$mode" ] && [ "$mode" != "--deep" ]; then
  usage >&2
  exit 2
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '缺少工具: %s\n' "$1" >&2
    exit 127
  }
}

require_cmd docker
require_cmd sha256sum

dump="$backup_dir/database.dump"
[ -f "$dump" ] || {
  printf '找不到备份文件: %s\n' "$dump" >&2
  exit 2
}

if [ -f "$backup_dir/SHA256SUMS" ]; then
  (cd "$backup_dir" && sha256sum -c SHA256SUMS)
fi

docker run --rm \
  -v "$backup_dir:/backup:ro" \
  postgres:18-alpine \
  pg_restore --list /backup/database.dump >/dev/null

if [ "$mode" = "--deep" ]; then
  container="sub2api-backup-verify-$(date +%Y%m%d%H%M%S)-$$"
  cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  docker run -d --name "$container" \
    -e POSTGRES_USER=sub2api \
    -e POSTGRES_PASSWORD=verify-only \
    -e POSTGRES_DB=sub2api_verify \
    -v "$backup_dir:/backup:ro" \
    postgres:18-alpine >/dev/null

  for _ in $(seq 1 60); do
    if docker exec "$container" pg_isready -U sub2api -d sub2api_verify >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  docker exec "$container" pg_restore -U sub2api -d sub2api_verify --clean --if-exists /backup/database.dump
  docker exec "$container" psql -U sub2api -d sub2api_verify -P pager=off -At -c \
    "select 'users='||count(*) from users union all select 'accounts='||count(*) from accounts union all select 'api_keys='||count(*) from api_keys union all select 'usage_logs='||count(*) from usage_logs;"
fi

printf '备份校验通过: %s\n' "$backup_dir"
