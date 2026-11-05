set -euo pipefail
set -a; . /config/.env; set +a

log()  { echo "[$(date '+%F %T')] $*"; }
ping() { [ -n "${HC_URL:-}" ] || return 0; curl -fsS -m 10 --retry 3 "${HC_URL}${1:-}" >/dev/null || true; }

format_count() {
  printf '%d' "$1" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta'
}

human_size() {
  awk -v b="$1" 'BEGIN{
    split("B KiB MiB GiB TiB", u, " ");
    i=1; while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf "%.2f %s", b, u[i]
  }'
}

# content_type: text/plain or text/html
_send_mail() {
  [ -n "${SMTP_HOST:-}" ] || return 0
  local subject="$1" body="$2" content_type="$3"
  local opts=()
  # Real relays (Gmail etc.) need auth + STARTTLS; local test servers like Mailpit don't.
  [ -n "${SMTP_USER:-}" ] && opts=(--ssl-reqd --user "${SMTP_USER}:${SMTP_PASSWORD}")

  local from_header="$MAIL_FROM"
  [ -n "${MAIL_FROM_NAME:-}" ] && from_header="${MAIL_FROM_NAME} <${MAIL_FROM}>"

  # MAIL_TO may be a comma-separated list of recipients.
  local -a recipients rcpt_opts
  IFS=',' read -ra recipients <<< "$MAIL_TO"
  for r in "${recipients[@]}"; do
    r="$(echo "$r" | xargs)"
    [ -n "$r" ] && rcpt_opts+=(--mail-rcpt "$r")
  done

  printf 'From: %s\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: %s; charset=UTF-8\r\n\r\n%s\r\n' \
    "$from_header" "$MAIL_TO" "$subject" "$content_type" "$body" | \
  curl -fsS -m 15 --retry 3 \
    "smtp://${SMTP_HOST}:${SMTP_PORT}" \
    --mail-from "$MAIL_FROM" "${rcpt_opts[@]}" \
    "${opts[@]}" \
    -T - >/dev/null || true
}

mail()      { _send_mail "$1" "$2" "text/plain"; }
mail_html() { _send_mail "$1" "$2" "text/html"; }
