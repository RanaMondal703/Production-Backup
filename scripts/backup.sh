#!/usr/bin/env bash
source /scripts/common.sh

ORG_NAME="${MAIL_ORG_NAME:-Aircargo}"
HOST_LABEL="${MAIL_HOST_LABEL:-aci-prod}"

render_email() {
  local content
  content=$(cat /scripts/email_template.html)
  for key in ACCENT TITLE SUBTITLE ORG_NAME STATUS LAST_BACKUP SNAPSHOT_ID STORAGE_USED TAGS PATHS HOST_LABEL GENERATED; do
    content=${content//"{{$key}}"/${!key}}
  done
  echo "$content"
}

START=$(date '+%F %T %Z')
trap '
  NOW=$(date "+%F %T %Z")
  log "BACKUP FAILED"
  ping /fail
  ACCENT="#C0392B"
  TITLE="Action required"
  SUBTITLE="$(date "+%A, %d %B %Y at %H:%M")"
  STATUS="Failed"
  LAST_BACKUP="N/A"
  SNAPSHOT_ID="N/A"
  STORAGE_USED="N/A"
  TAGS="N/A"
  PATHS="N/A"
  GENERATED="$NOW"
  HTML=$(render_email)
  mail_html "ACI Backup Notification" "$HTML"
' ERR
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

SNAPSHOT_JSON=$(restic snapshots --latest 1 --json)
SNAPSHOT_ID=$(echo "$SNAPSHOT_JSON" | jq -r '.[0].short_id')
TAGS=$(echo "$SNAPSHOT_JSON" | jq -r '.[0].tags | join(", ")')
PATHS=$(echo "$SNAPSHOT_JSON" | jq -r '.[0].paths | join(", ")')
STATS_JSON=$(restic stats latest --mode raw-data --json)
RAW_SIZE=$(echo "$STATS_JSON" | jq -r '.total_size')
END=$(date '+%F %T %Z')

log "backup done"
ping ""

ACCENT="#1E7E34"
TITLE="All systems normal"
SUBTITLE="$(date '+%A, %d %B %Y at %H:%M')"
STATUS="Completed successfully"
LAST_BACKUP="$(date '+%d %b %Y')"
STORAGE_USED=$(human_size "$RAW_SIZE")
GENERATED="$END"
HTML=$(render_email)
mail_html "ACI Backup Notification" "$HTML"
