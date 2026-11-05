# Production Backup

Containerized nightly backup for a production environment: exports RustFS buckets,
snapshots a consistent copy of the Openinary SQLite DB, then backs up everything (apps
data + staging export) to a restic repository. Sends an HTML email report and pings a
healthcheck URL on success/failure.

Host/organization names below (`aci-prod`, `Aircargo`, etc.) are just the defaults baked
into this particular deployment — rename them for your own environment via
`MAIL_ORG_NAME`, `MAIL_HOST_LABEL`, and the `hostname` in `docker-compose.yml`.

## How it works

- `Dockerfile` builds an Alpine image with `restic`, `rclone`, `sqlite`, `curl`, `jq`, and
  runs `crond` in the foreground.
- `crontab` schedules:
  - `scripts/backup.sh` nightly at 04:30
  - `scripts/maintenance.sh` weekly on Sunday at 07:00 (restic `forget` + `check`)
- `scripts/common.sh` loads `/config/.env`, and provides logging, healthcheck pings
  (`ping`), size formatting, and SMTP email helpers (`mail` / `mail_html`).
- `scripts/backup.sh`:
  1. Syncs each RustFS bucket in `RUSTFS_BUCKETS` to `/staging/rustfs/<bucket>` via
     `rclone`.
  2. Takes a consistent copy of Openinary's `auth.db` via `sqlite3 .backup` (falls back to
     a raw file copy if that fails).
  3. Runs `restic backup` over `/source/apps` and `/staging`, excluding paths listed in
     `scripts/excludes.txt`.
  4. Emails a status report (`scripts/email_template.html`) and pings the healthcheck URL.
- `scripts/maintenance.sh` prunes old snapshots (`--keep-daily 7 --keep-weekly 5
  --keep-monthly 12 --keep-yearly 2`) and verifies 10% of repository data.
- `scripts/run.sh` is a helper to run any one-off command with `.env` loaded (e.g. for
  manual `restic restore`/`rclone` operations inside the container).

## Setup

1. Copy `.env.example` to `.env` and fill in the values (restic repo + password, AWS/S3 or
   RustFS/rclone credentials, SMTP settings, healthcheck URL, etc.). `.env` is gitignored.
2. Review `scripts/excludes.txt` and adjust paths for what should be skipped from the
   `/source/apps` backup.
3. Build and start the container:

   ```bash
   docker compose up -d --build
   ```

4. The container mounts `/opt/apps` (read-only) as backup source, `./scripts` as the script
   directory, and keeps a restic cache volume. The `shared_net` network is expected to
   already exist externally.

## Manual operations

Run any command inside the container with the environment loaded, e.g.:

```bash
docker compose exec backup bash /scripts/run.sh restic snapshots
docker compose exec backup bash /scripts/run.sh restic restore latest --target /staging/restore
```

## Environment variables

See `.env.example` for the full list, including:

- `RESTIC_REPOSITORY`, `RESTIC_PASSWORD` — restic backend and encryption password.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION` — restic's S3-compatible
  backend credentials.
- `RUSTFS_BUCKETS`, `RCLONE_CONFIG_RUSTFS_*` — RustFS source and rclone remote config.
- `HC_URL` — healthcheck ping base URL.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `MAIL_FROM`, `MAIL_FROM_NAME`,
  `MAIL_TO`, `MAIL_ORG_NAME`, `MAIL_HOST_LABEL` — email report settings.
