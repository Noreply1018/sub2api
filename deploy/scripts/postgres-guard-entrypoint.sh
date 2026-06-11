#!/usr/bin/env sh
set -eu

DATA_DIR="${PGDATA:-/var/lib/postgresql/data}"
GUARD_DIR="${POSTGRES_GUARD_DIR:-/guard}"
SENTINEL="${POSTGRES_GUARD_SENTINEL:-$GUARD_DIR/.postgres-initialized}"
ALLOW_EMPTY_INIT="${ALLOW_EMPTY_DATABASE_INIT:-false}"
OFFICIAL_ENTRYPOINT="${POSTGRES_OFFICIAL_ENTRYPOINT:-/usr/local/bin/docker-entrypoint.sh}"

log() {
  printf '%s\n' "[postgres-guard] $*"
}

fail() {
  log "ERROR: $*"
  exit 64
}

if [ ! -d "$DATA_DIR" ]; then
  fail "PostgreSQL data directory does not exist: $DATA_DIR"
fi

mkdir -p "$GUARD_DIR"

if [ -s "$DATA_DIR/PG_VERSION" ]; then
  if [ ! -f "$SENTINEL" ]; then
    log "database exists; creating guard sentinel at $SENTINEL"
    date -Is > "$SENTINEL"
  fi
  exec "$OFFICIAL_ENTRYPOINT" "$@"
fi

if [ -f "$SENTINEL" ] && [ "$ALLOW_EMPTY_INIT" != "true" ]; then
  fail "guard sentinel exists but $DATA_DIR/PG_VERSION is missing. Refusing to initialize an empty database. Restore the data directory or set ALLOW_EMPTY_DATABASE_INIT=true only for an intentional reset."
fi

if [ "$ALLOW_EMPTY_INIT" = "true" ]; then
  log "ALLOW_EMPTY_DATABASE_INIT=true; allowing empty database initialization"
else
  log "no guard sentinel found; allowing first database initialization"
fi

date -Is > "$SENTINEL"
exec "$OFFICIAL_ENTRYPOINT" "$@"
