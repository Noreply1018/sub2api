-- users: encrypted display copy for admin-managed homepage login keys.
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_key_encrypted text;
