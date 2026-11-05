#!/usr/bin/env bash
source /scripts/common.sh
trap 'log "MAINTENANCE FAILED"; ping /fail' ERR
log "maintenance start"
restic forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 2 --prune
restic check --read-data-subset=10%
log "maintenance done"
