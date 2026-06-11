#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
用法:
  tools/backup_db.sh prod
  tools/backup_db.sh dev

环境变量:
  SUB2API_BACKUP_ROOT   备份根目录，默认 /home/lh/backups/sub2api-auto
  SUB2API_KEEP_BACKUPS  每个环境保留的最近备份数量，默认 30
  SUB2API_BACKUP_VERIFY 备份后校验模式: list, deep, none；默认 list
USAGE
}

env_name="${1:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$env_name" in
  prod)
    pg_container="sub2api-postgres"
    app_dir="/home/lh/apps/sub2api"
    compose_file="$app_dir/docker-compose.yml"
    ;;
  dev)
    pg_container="sub2api-postgres-dev"
    app_dir="/home/lh/projects/sub2api/deploy"
    compose_file="$app_dir/docker-compose.dev.yml"
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

backup_root="${SUB2API_BACKUP_ROOT:-/home/lh/backups/sub2api-auto}"
keep_backups="${SUB2API_KEEP_BACKUPS:-30}"
verify_mode="${SUB2API_BACKUP_VERIFY:-list}"
timestamp="$(date +%Y%m%d-%H%M%S)"
dest="$backup_root/$env_name/$timestamp"
tmp_dump="/tmp/sub2api-$env_name-$timestamp.dump"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '缺少工具: %s\n' "$1" >&2
    exit 127
  }
}

require_cmd docker
require_cmd sha256sum
require_cmd tar

mkdir -p "$dest"

docker inspect "$pg_container" >/dev/null
docker exec "$pg_container" pg_dump -U sub2api -d sub2api -Fc -f "$tmp_dump"
docker cp "$pg_container:$tmp_dump" "$dest/database.dump"
docker exec "$pg_container" rm -f "$tmp_dump" >/dev/null

tar -C "$app_dir" -czf "$dest/app-config.tgz" .env "$(basename "$compose_file")" data

docker exec "$pg_container" psql -U sub2api -d sub2api -P pager=off -At -c \
  "select 'users='||count(*) from users union all select 'accounts='||count(*) from accounts union all select 'api_keys='||count(*) from api_keys union all select 'usage_logs='||count(*) from usage_logs union all select 'settings='||count(*) from settings;" \
  > "$dest/table-counts.txt"

sha256sum "$dest/database.dump" "$dest/app-config.tgz" > "$dest/SHA256SUMS"
{
  printf 'environment=%s\n' "$env_name"
  printf 'created_at=%s\n' "$(date -Is)"
  printf 'postgres_container=%s\n' "$pg_container"
  docker inspect "$pg_container" --format 'postgres_image={{.Config.Image}}'
  docker inspect "$pg_container" --format 'postgres_container_id={{.Id}}'
} > "$dest/manifest.txt"

case "$verify_mode" in
  list)
    "$script_dir/verify_db_backup.sh" "$dest" >/dev/null
    ;;
  deep)
    "$script_dir/verify_db_backup.sh" "$dest" --deep >/dev/null
    ;;
  none)
    ;;
  *)
    printf '无效 SUB2API_BACKUP_VERIFY: %s\n' "$verify_mode" >&2
    exit 2
    ;;
esac

if [[ "$keep_backups" =~ ^[0-9]+$ ]] && [ "$keep_backups" -gt 0 ]; then
  mapfile -t old_backups < <(find "$backup_root/$env_name" -mindepth 1 -maxdepth 1 -type d | sort -r | tail -n +$((keep_backups + 1)))
  for old in "${old_backups[@]}"; do
    rm -rf "$old"
  done
fi

printf '%s\n' "$dest"
