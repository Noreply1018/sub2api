---
name: sub2api-upstream-sync
description: Use for this sub2api fork when checking Wei-Shaw/sub2api upstream updates, comparing official tags or upstream/main with local-custom, planning or performing upstream merges into this local fork, preserving local customization, validating the 8081 development deployment after an upstream sync, or handling requests that mention upstream sync, official version updates, fork merge, local-custom, origin/upstream divergence, or merging official sub2api releases. Does not promote to 8080 production.
---

# Sub2API Upstream Sync

## Scope

Use this skill to safely bring official `Wei-Shaw/sub2api` changes into this local second-development fork.

This skill covers:

- checking whether upstream has newer tags or commits;
- creating an integration branch for upstream sync;
- merging `upstream/main` or a requested upstream tag;
- preserving local fork customizations;
- validating the merged result on the 8081 development deployment;
- merging the validated integration branch back into `local-custom` when the user confirms.

This skill does not cover promotion to the 8080 production deployment. For dev-to-prod release, use `sub2api-release-flow`.

## Repository Assumptions

- Repository path: `/home/lh/projects/sub2api`
- Local second-development mainline: `local-custom`
- Personal fork remote: `origin`
- Official remote: `upstream` (`Wei-Shaw/sub2api`)
- Development deployment: `http://127.0.0.1:8081`
- Production deployment: `http://127.0.0.1:8080`

Before nontrivial sync work, read `LOCAL_DEV.md` and `docs-dev/README.md`. If the task may restart services or mentions 8081/8080, also read `.agents/skills/sub2api-release-flow/SKILL.md`.

## Safety Rules

- Do not touch 8080 production during upstream sync unless the user explicitly asks for production release.
- Do not overwrite production `.env`, `data/config.yaml`, PostgreSQL data, or Redis data.
- Do not directly merge upstream into `local-custom` without first using an integration branch, unless the user explicitly overrides this workflow.
- Do not rebase `local-custom`; preserve fork history with merge commits.
- Do not push to `origin` unless the user explicitly asks.
- Do not treat official README positioning as this fork's product direction.
- Do not remove or weaken existing local customizations just because upstream lacks them.

## Local Customizations To Protect

Preserve these unless the user explicitly asks to remove them:

- `LOCAL_DEV.md`
- `docs-dev/**`
- `.agents/skills/**`
- `tools/promote_dev_to_prod.sh`
- `tools/visual_check_personal_usage.mjs`
- `tools/check_frontend_bundle_text.mjs`
- personal/simple mode behavior that hides billing, balance, recharge, rate, quota, and permission-gated UI semantics where applicable;
- 8081 development vs 8080 production deployment separation.

When conflicts touch gateway, billing, usage, auth, permissions, payment, database schema, or admin/user usage UI, inspect the code semantically. Do not mechanically choose ours/theirs.

## Phase 1: Check Upstream Only

Use this phase when the user asks whether official sub2api has updates.

```bash
git fetch upstream --tags --prune
git branch --show-current
git status --short
git tag --sort=-v:refname | head -20
git log --decorate --oneline --date=short --pretty=format:'%h %ad %d %s' -12 upstream/main
git rev-list --left-right --count HEAD...upstream/main
```

Also compare the current local version with upstream:

```bash
git describe --tags --always --dirty
git show HEAD:backend/cmd/server/VERSION 2>/dev/null || true
git show upstream/main:backend/cmd/server/VERSION 2>/dev/null || true
```

Report:

- latest upstream tag and `upstream/main` commit;
- current local branch and version;
- local-only and upstream-only commit counts;
- notable upstream changes from recent commit subjects;
- that no code was changed.

## Phase 2: Create Integration Branch

Use this phase only after the user asks to start merging.

Start from a clean worktree. If unrelated user changes exist, do not overwrite them; either work around them or ask for direction if they block the sync.

```bash
git switch local-custom
git status --short
git fetch upstream --tags --prune
git branch backup/local-custom-before-upstream-vX.Y.Z 2>/dev/null || true
git switch -c merge/upstream-vX.Y.Z
```

Choose the target:

- Prefer `upstream/main` when syncing to the official current baseline, especially when `main` contains version-sync commits after the latest tag.
- Use a specific tag only when the user asks for that exact tag.

Merge with a merge commit:

```bash
git merge --no-ff upstream/main
```

## Phase 3: Resolve Conflicts

First inspect conflicts:

```bash
git status --short
rg -n '<<<<<<<|=======|>>>>>>>' .
```

Resolution rules:

- Local project docs, local release scripts, and local skill files are normally kept.
- Upstream compatibility, security, gateway, scheduler, usage, proxy, and API bugfixes are normally absorbed.
- For user/admin usage pages, preserve `hidesBillingUi` and personal/simple mode semantics while integrating upstream token/error-request improvements.
- For Ent schemas and migrations, keep upstream schema changes unless they conflict with local schema customizations; then inspect migration order and generated code.
- For generated files such as Wire/Ent output, prefer consistency with source schema/provider changes and run the relevant generator only if the repository already expects it.

After manual edits:

```bash
gofmt -w <changed-go-files>
git add <resolved-files>
git status --short | rg '^(UU|AA|DD|DU|UD|AU|UA)' || true
git diff --check
```

## Phase 4: Validate Integration Branch

Run frontend and Docker validation:

```bash
cd /home/lh/projects/sub2api/frontend
pnpm install --frozen-lockfile
pnpm typecheck
```

Build the development image from the repo root:

```bash
cd /home/lh/projects/sub2api
docker compose -f deploy/docker-compose.dev.yml build sub2api
```

If local `go version` is older than `backend/go.mod`, do not rely on bare `go test` as the primary check. Prefer Docker build with the repository Dockerfile.

Restart only the 8081 app container:

```bash
docker compose --env-file deploy/.env -f deploy/docker-compose.dev.yml up -d --no-deps sub2api
```

Verify 8081:

```bash
curl -fsS http://127.0.0.1:8081/health
curl -fsS http://127.0.0.1:8081/api/v1/settings/public
docker logs --tail 120 sub2api-dev
```

For personal/simple mode UI, use real browser validation:

```bash
node tools/visual_check_personal_usage.mjs
```

Do not use bundle text hits for billing words as failure by itself; translation bundles may contain strings that are not visible in the active UI. Use visible text checks.

## Phase 5: Commit Integration Branch

After validation:

```bash
git status --short
git commit --no-edit
```

If the merge commit already exists or `git merge` created it, ensure the final integration branch is clean:

```bash
git status --short --branch
git log --oneline --decorate -5
```

Report:

- integration branch name;
- merge commit hash;
- upstream target merged;
- conflicts resolved;
- validation results;
- 8081 health and `run_mode`/version;
- that 8080 production was not touched.

## Phase 6: Merge Back To Local Mainline

Only do this after the user confirms the integration branch is acceptable.

```bash
git switch local-custom
git merge --no-ff merge/upstream-vX.Y.Z -m "chore: merge upstream vX.Y.Z"
```

Then verify:

```bash
git status --short --branch
curl -fsS http://127.0.0.1:8081/health
curl -fsS http://127.0.0.1:8081/api/v1/settings/public
node tools/visual_check_personal_usage.mjs
git rev-list --left-right --count origin/local-custom...local-custom
```

Do not push or promote to 8080 unless the user explicitly asks.

## Final Reporting

When finished, state:

- whether changes are only on an integration branch or already merged into `local-custom`;
- exact branch and commit hash;
- whether `origin/local-custom` is ahead/behind;
- 8081 URL and health result;
- version and `run_mode`;
- personal/simple UI validation result;
- whether 8080 production was untouched;
- next available actions: user review on 8081, push to origin, or production promotion via `sub2api-release-flow`.
