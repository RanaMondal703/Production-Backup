#!/usr/bin/env bash
# helper: run any command with the .env loaded
set -a; . /config/.env; set +a
exec "$@"
