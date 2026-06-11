#!/usr/bin/env bash
set -euo pipefail

check_env() {
  local name="$1"
  local app_dir="$2"
  local compose_file="$3"
  local pg_container="$4"
  local backup_root="${SUB2API_BACKUP_ROOT:-/home/lh/backups/sub2api-auto}"

  printf '== %s ==\n' "$name"
  if docker exec "$pg_container" test -s /var/lib/postgresql/data/PG_VERSION >/dev/null 2>&1; then
    printf 'PG_VERSION: ok\n'
  else
    printf 'PG_VERSION: missing\n'
  fi

  if [ -f "$app_dir/data/.postgres-initialized" ]; then
    printf 'guard sentinel: ok\n'
  else
    printf 'guard sentinel: missing\n'
  fi

  expected_system_id=""
  if [ -f "$app_dir/data/.postgres-system-identifier" ]; then
    expected_system_id="$(tr -d '[:space:]' < "$app_dir/data/.postgres-system-identifier")"
    printf 'expected system id: %s\n' "$expected_system_id"
  else
    printf 'expected system id: missing\n'
  fi

  actual_system_id=""
  control_tmp="$(mktemp /tmp/sub2api-pg-control.XXXXXX)"
  if docker exec "$pg_container" pg_controldata /var/lib/postgresql/data >"$control_tmp" 2>/dev/null; then
    actual_system_id="$(awk -F: '/Database system identifier/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' "$control_tmp")"
    rm -f "$control_tmp"
    printf 'actual system id: %s\n' "$actual_system_id"
    if [ -n "$expected_system_id" ] && [ "$expected_system_id" = "$actual_system_id" ]; then
      printf 'system id match: ok\n'
    elif [ -n "$expected_system_id" ]; then
      printf 'system id match: mismatch\n'
    fi
  else
    rm -f "$control_tmp"
    printf 'actual system id: unreadable\n'
  fi

  if grep -q 'postgres-guard-entrypoint.sh' "$compose_file"; then
    printf 'compose guard: ok\n'
  else
    printf 'compose guard: missing\n'
  fi

  if docker inspect "$pg_container" >/dev/null 2>&1; then
    docker exec "$pg_container" psql -U sub2api -d sub2api -P pager=off -At -c \
      "select 'users='||count(*) from users union all select 'accounts='||count(*) from accounts union all select 'api_keys='||count(*) from api_keys union all select 'usage_logs='||count(*) from usage_logs;" \
      | sed 's/^/table /'
  else
    printf 'container: missing %s\n' "$pg_container"
  fi

  latest="$(find "$backup_root/$name" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"
  if [ -n "$latest" ]; then
    printf 'latest backup: %s\n' "$latest"
  else
    printf 'latest backup: missing\n'
  fi
  printf '\n'
}

check_env prod /home/lh/apps/sub2api /home/lh/apps/sub2api/docker-compose.yml sub2api-postgres
check_env dev /home/lh/projects/sub2api/deploy /home/lh/projects/sub2api/deploy/docker-compose.dev.yml sub2api-postgres-dev
