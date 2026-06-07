---
name: sub2api-release-flow
description: Use for this sub2api fork when promoting validated changes from the 8081 development/debug deployment to the 8080 production deployment, rebuilding or retagging Docker images, checking the two local Compose environments, planning releases, or handling requests that mention dev-to-prod migration, formal version, 8081, 8080, sub2api-dev, sub2api, deploy/docker-compose.dev.yml, or /home/lh/apps/sub2api. Enforces preserving production data by default.
---

# Sub2API Release Flow

## Overview

Use this skill to move code and feature changes from the local debug deployment to the formal deployment without overwriting production data. Treat 8081 as the disposable validation surface and 8080 as the persistent service. For development validation, only rebuild or restart the 8081 deployment unless the user explicitly asks to promote to 8080.

## Environment Map

Development/debug deployment:

- Path: `/home/lh/projects/sub2api`
- Compose file: `deploy/docker-compose.dev.yml`
- App container: `sub2api-dev`
- Database container: `sub2api-postgres-dev`
- Redis container: `sub2api-redis-dev`
- URL: `http://127.0.0.1:8081`
- Purpose: development, testing, temporary data, and destructive experiments.

Production/formal deployment:

- Path: `/home/lh/apps/sub2api`
- Compose file: `/home/lh/apps/sub2api/docker-compose.yml`
- App container: `sub2api`
- Database container: `sub2api-postgres`
- Redis container: `sub2api-redis`
- URL: `http://127.0.0.1:8080`
- Purpose: stable daily use and persistent production data.

## Data Safety Rules

Default release behavior is code/image promotion only. Preserve production PostgreSQL, Redis, `.env`, and `data/config.yaml`.

Do not do these unless the user explicitly asks for a full data migration and confirms the impact:

- Do not restore a dump from `sub2api-postgres-dev` into `sub2api-postgres`.
- Do not copy `deploy/postgres_data` or `deploy/redis_data` into `/home/lh/apps/sub2api`.
- Do not overwrite `/home/lh/apps/sub2api/.env` with `deploy/.env`.
- Do not overwrite `/home/lh/apps/sub2api/data/config.yaml` with `deploy/data/config.yaml`.
- Do not run destructive database commands against `sub2api-postgres` without a fresh backup.

If a schema migration is required, apply the migration to the production database after taking a backup. Migrate schema, not development data.

## Standard Workflow

1. Read the repo context before nontrivial work: `LOCAL_DEV.md`, `docs-dev/README.md`, and the relevant `docs-dev/*` page.
2. Record complex feature work in `docs-dev/backlog.md` before implementation when it touches gateway, billing/usage, auth, permissions, payment, or database behavior.
3. Implement and validate the change on the development deployment at `8081`.
4. Build or rebuild the development image from `/home/lh/projects/sub2api`.
5. Verify `8081` with health checks, targeted API calls, logs, and database checks as appropriate.
6. Back up production before promotion.
7. Promote only the validated code/image to `8080`; keep production data directories and environment files in place.
8. Recreate or restart only the production app container unless a migration requires database coordination.
9. Verify `8080` health, logs, image identity, and representative data counts.
10. Commit repository changes after verification when changes were made by Codex.

## Personal/Simple UI Validation

For personal/simple mode frontend work, especially hiding billing, balance, recharge, rate, quota, or permission-gated UI semantics:

- Do not rely only on source diff, typecheck, unit tests, or frontend build.
- Confirm the runtime configuration chain on `8081`, including `/api/v1/settings/public` and the expected `run_mode`.
- Use a real browser against `http://127.0.0.1:8081`, save screenshots, and assert visible text from `document.body.innerText`.
- Required checks for personal usage UI: `/admin/usage` and `/usage` must still show Token information, and must not show `总消费`, `Total Cost`, `$`, `Billing Control`, or `计费管理`.
- Prefer the fixed local script when applicable:

```bash
node tools/visual_check_personal_usage.mjs
```

The script defaults to `http://127.0.0.1:8081` and `admin@sub2api.local` / `admin123456`. Override with `SUB2API_BASE_URL`, `SUB2API_ADMIN_EMAIL`, `SUB2API_ADMIN_PASSWORD`, `SUB2API_USER_EMAIL`, `SUB2API_USER_PASSWORD`, `SUB2API_SCREENSHOT_DIR`, or `CHROME_BIN` when needed.

Do not mark a backlog item `done` until the user has explicitly accepted it. Before that, keep it as `doing` or `review`.

## Useful Commands

Check both services:

```bash
curl http://127.0.0.1:8081/health
curl http://127.0.0.1:8080/health
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | rg 'sub2api'
```

Run the development deployment:

```bash
cd /home/lh/projects/sub2api/deploy
docker compose -f docker-compose.dev.yml up --build -d
```

Back up production before promotion:

```bash
TS=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/home/lh/backups/sub2api-prod-before-release-$TS"
mkdir -p "$BACKUP_DIR"
docker exec sub2api-postgres pg_dump -U sub2api -d sub2api -Fc -f /tmp/prod-before-release.dump
docker cp sub2api-postgres:/tmp/prod-before-release.dump "$BACKUP_DIR/prod-before-release.dump"
tar -C /home/lh/apps -czf "$BACKUP_DIR/prod-app-dir.tgz" sub2api/.env sub2api/docker-compose.yml sub2api/data
```

Promote the validated image without changing production data:

```bash
docker tag deploy-sub2api:latest weishaw/sub2api:latest
cd /home/lh/apps/sub2api
docker compose up -d --force-recreate sub2api
```

Verify production after promotion:

```bash
curl http://127.0.0.1:8080/health
docker logs --tail 120 sub2api
docker inspect sub2api --format '{{.Image}}'
docker exec sub2api-postgres psql -U sub2api -d sub2api -P pager=off -c "select count(*) from users; select count(*) from api_keys; select count(*) from accounts; select count(*) from usage_logs;"
```

## Reporting

When finishing a promotion or release plan, report:

- What was promoted.
- Whether production data was preserved.
- Backup directory, if a backup was created.
- Health-check results for `8080` and, when relevant, `8081`.
- Any warnings left in logs and whether they are expected.
