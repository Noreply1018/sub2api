-- users: web login key hash for one-field homepage login.
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_key_hash varchar(64);

CREATE UNIQUE INDEX IF NOT EXISTS users_login_key_hash_active_idx
    ON users (login_key_hash)
    WHERE login_key_hash IS NOT NULL AND deleted_at IS NULL;
