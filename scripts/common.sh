set -euo pipefail
set -a; . /config/.env; set +a

log()  { echo "[$(date '+%F %T')] $*"; }
ping() { [ -n "${HC_URL:-}" ] || return 0; curl -fsS -m 10 --retry 3 "${HC_URL}${1:-}" >/dev/null || true; }
