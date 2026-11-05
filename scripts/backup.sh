#!/usr/bin/env bash
source /scripts/common.sh
trap 'log "BACKUP FAILED"; ping /fail' ERR
ping /start
log "backup start"

# 1. Export RustFS buckets (includes the Spatie DB dumps) to staging
for b in $RUSTFS_BUCKETS; do
  log "exporting bucket $b"
  rclone sync "rustfs:$b" "/staging/rustfs/$b" --transfers 8 --checkers 16 --log-level NOTICE
done

# 2. Consistent copy of Openinary's SQLite DB
mkdir -p /staging/openinary
SRC=/source/apps/data/openinary/data/auth.db
sqlite3 -readonly "$SRC" ".backup '/staging/openinary/auth.db'" || {
  log "sqlite .backup failed, falling back to raw copy"
  cp -a "$SRC"* /staging/openinary/
}

# 3. Snapshot configs, secrets, private files and the staging export
restic backup /source/apps /staging \
  --tag nightly \
  --exclude-file=/scripts/excludes.txt

restic snapshots --latest 1
log "backup done"
ping ""
