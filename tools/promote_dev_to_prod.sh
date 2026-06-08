#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/home/lh/projects/sub2api}"
PROD_DIR="${PROD_DIR:-/home/lh/apps/sub2api}"
DEV_IMAGE="${DEV_IMAGE:-deploy-sub2api:latest}"
PROD_IMAGE="${PROD_IMAGE:-weishaw/sub2api:latest}"
BACKUP_ROOT="${BACKUP_ROOT:-/home/lh/backups}"

YES=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: tools/promote_dev_to_prod.sh --yes
       tools/promote_dev_to_prod.sh --dry-run

Safely promotes the validated 8081 dev image to the 8080 production app
container. Production PostgreSQL, Redis, .env, and data/config.yaml are
preserved. A production backup is always created before --yes promotion.

Options:
  --yes       Perform the promotion.
  --dry-run   Print and validate the promotion plan without changing prod.
  -h, --help  Show this help.

Env overrides:
  ROOT_DIR, PROD_DIR, DEV_IMAGE, PROD_IMAGE, BACKUP_ROOT
EOF
}

run() {
  printf '+ %s\n' "$*"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$YES" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
  echo "--yes and --dry-run cannot be used together" >&2
  exit 2
fi

if [[ "$YES" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
  usage >&2
  exit 2
fi

command -v docker >/dev/null
command -v curl >/dev/null

echo "Promotion plan:"
echo "  root:       $ROOT_DIR"
echo "  production: $PROD_DIR"
echo "  image:      $DEV_IMAGE -> $PROD_IMAGE"
echo "  mode:       $([[ "$DRY_RUN" -eq 1 ]] && echo dry-run || echo promote)"

curl -fsS http://127.0.0.1:8081/health >/dev/null
curl -fsS http://127.0.0.1:8080/health >/dev/null
docker image inspect "$DEV_IMAGE" >/dev/null
test -f "$PROD_DIR/docker-compose.yml"

BACKUP_DIR=""
if [[ "$DRY_RUN" -eq 0 ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$BACKUP_ROOT/sub2api-prod-before-release-$TS"
  run mkdir -p "$BACKUP_DIR"
  run docker exec sub2api-postgres pg_dump -U sub2api -d sub2api -Fc -f /tmp/prod-before-release.dump
  run docker cp sub2api-postgres:/tmp/prod-before-release.dump "$BACKUP_DIR/prod-before-release.dump"
  run tar -C /home/lh/apps -czf "$BACKUP_DIR/prod-app-dir.tgz" sub2api/.env sub2api/docker-compose.yml sub2api/data
fi

run docker tag "$DEV_IMAGE" "$PROD_IMAGE"
if [[ "$DRY_RUN" -eq 0 ]]; then
  (
    cd "$PROD_DIR"
    run docker compose up -d --force-recreate sub2api
  )
else
  echo "+ cd $PROD_DIR && docker compose up -d --force-recreate sub2api"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  curl -fsS http://127.0.0.1:8080/health
  printf '\n'
  docker inspect sub2api --format '{{.Image}} {{.Config.Image}}'
  docker exec sub2api-postgres psql -U sub2api -d sub2api -P pager=off -c "select count(*) as users from users; select count(*) as api_keys from api_keys; select count(*) as accounts from accounts; select count(*) as usage_logs from usage_logs;"
  echo "Backup directory: $BACKUP_DIR"
fi
