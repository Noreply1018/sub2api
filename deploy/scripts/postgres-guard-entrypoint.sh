#!/usr/bin/env sh
set -eu

DATA_DIR="${PGDATA:-/var/lib/postgresql/data}"
GUARD_DIR="${POSTGRES_GUARD_DIR:-/guard}"
SENTINEL="${POSTGRES_GUARD_SENTINEL:-$GUARD_DIR/.postgres-initialized}"
SYSTEM_ID_FILE="${POSTGRES_SYSTEM_IDENTIFIER_FILE:-$GUARD_DIR/.postgres-system-identifier}"
ALLOW_EMPTY_INIT="${ALLOW_EMPTY_DATABASE_INIT:-false}"
OFFICIAL_ENTRYPOINT="${POSTGRES_OFFICIAL_ENTRYPOINT:-/usr/local/bin/docker-entrypoint.sh}"
PG_CONTROLDATA="${POSTGRES_PG_CONTROLDATA:-pg_controldata}"

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

current_system_id() {
  "$PG_CONTROLDATA" "$DATA_DIR" | awk -F: '/Database system identifier/ {gsub(/^[ \t]+/, "", $2); print $2; exit}'
}

if [ -s "$DATA_DIR/PG_VERSION" ]; then
  if [ ! -f "$SENTINEL" ]; then
    log "database exists; creating guard sentinel at $SENTINEL"
    date -Is > "$SENTINEL"
  fi
  system_id="$(current_system_id)"
  if [ -z "$system_id" ]; then
    fail "could not read PostgreSQL database system identifier from $DATA_DIR"
  fi
  if [ -f "$SYSTEM_ID_FILE" ]; then
    expected_system_id="$(tr -d '[:space:]' < "$SYSTEM_ID_FILE")"
    if [ "$system_id" != "$expected_system_id" ]; then
      fail "database system identifier mismatch. expected=$expected_system_id actual=$system_id. Refusing to start with a different PostgreSQL cluster."
    fi
  else
    log "recording database system identifier $system_id at $SYSTEM_ID_FILE"
    printf '%s\n' "$system_id" > "$SYSTEM_ID_FILE"
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
