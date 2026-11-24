#!/bin/bash
# Create Appsmith's first administrator from Railway variables (runs in the background next to
# supervisord, started by railway-start.sh). Until it succeeds, railway-healthz answers 503, so
# Railway never routes the public domain to an instance whose first-admin page is open.
#
#   ADMIN_EMAIL / ADMIN_PASSWORD / ADMIN_NAME   the administrator (password 8-48 characters)
#   ADMIN_PASSWORD_RESET=true                   set the password of ADMIN_EMAIL on this boot
#
# Deploy-form values never fail the deploy (STANDARD 8.29): an unusable password still creates
# the administrator, but with a random password nobody knows (the instance is "locked"); a
# valid ADMIN_PASSWORD on a later boot sets the real password. Passwords are never logged.
set -uo pipefail

STATE_DIR=/appsmith-stacks/.railway
READY_MARKER="${STATE_DIR}/admin-ready"
LOCK_MARKER="${STATE_DIR}/admin-locked"
APP="http://127.0.0.1:${APPSMITH_HTTP_PORT:-80}"
CADDY=/opt/caddy/caddy

log() { printf '[railway-admin] %s\n' "$*"; }
password_ok() { [ "${#1}" -ge 8 ] && [ "${#1}" -le 48 ] && [[ "$1" != *[[:cntrl:]]* ]]; }

wait_for_appsmith() {
  local waited=0
  until [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${APP}/api/v1/health")" = 200 ]; do
    if [ $((waited % 300)) -eq 0 ] && [ "${waited}" -gt 0 ]; then log "waiting for Appsmith to become healthy (${waited}s)"; fi
    sleep 10
    waited=$((waited + 10))
  done
}

# Prints true when Appsmith has no user yet, false when it has, nothing on error.
empty_instance() {
  curl -s --max-time 15 -H 'X-Requested-By: Appsmith' "${APP}/api/v1/users/me" \
    | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data") or {}; print("true" if d.get("emptyInstance") else "false")' 2>/dev/null
}

create_admin() {
  local email="$1" name="$2" pw="$3" origin="https://${RAILWAY_PUBLIC_DOMAIN:-localhost}" location
  location="$(curl -s -o /dev/null -w '%{redirect_url}' --max-time 60 -X POST "${APP}/api/v1/users/super" \
    -H "Origin: ${origin}" -H "Referer: ${origin}/setup/welcome" -H 'X-Requested-By: Appsmith' \
    --data-urlencode "name=${name}" --data-urlencode "email=${email}" --data-urlencode "password=${pw}" \
    --data-urlencode "allowCollectingAnonymousData=false" --data-urlencode "signupForNewsletter=false" \
    --data-urlencode "useCase=work")"
  if [[ "${location}" == *"error="* ]]; then
    log "WARNING: Appsmith refused the administrator: $(python3 -c 'import sys,urllib.parse as u; q=u.parse_qs(u.urlparse(sys.argv[1]).query); print(q.get("error",["?"])[0][:200])' "${location}")"
    return 1
  fi
  [ "$(empty_instance)" = false ]
}

db_url() {
  if [ -n "${APPSMITH_DB_URL:-}" ]; then
    printf '%s' "${APPSMITH_DB_URL}"
  else
    grep '^APPSMITH_DB_URL=' /appsmith-stacks/configuration/docker.env | tail -n 1 | cut -d= -f2-
  fi
}

# Appsmith stores BCrypt hashes (Spring BCryptPasswordEncoder); Caddy's hash-password makes one.
set_password() {
  local email="$1" pw="$2" hash out
  hash="$(printf '%s' "${pw}" | "${CADDY}" hash-password --algorithm bcrypt 2>/dev/null | tail -n 1)" || hash=""
  [[ "${hash}" == '$2'* ]] || { log "WARNING: could not hash the password; unchanged."; return 1; }
  out="$(RAILWAY_EMAIL="${email}" RAILWAY_HASH="${hash}" mongosh "$(db_url)" --quiet --eval '
    const r = db.user.updateOne({ email: process.env.RAILWAY_EMAIL.toLowerCase() },
                                { $set: { password: process.env.RAILWAY_HASH } });
    print(r.matchedCount);' 2>&1 | tail -n 1)"
  if [ "${out}" = 1 ]; then
    log "password of ${email} set from ADMIN_PASSWORD. Set ADMIN_PASSWORD_RESET back to false."
    return 0
  fi
  log "WARNING: no Appsmith user with e-mail ${email} (ADMIN_EMAIL); password unchanged."
  return 1
}

main() {
  local email="${ADMIN_EMAIL:-}" name="${ADMIN_NAME:-Admin}" pw="${ADMIN_PASSWORD:-}" state
  mkdir -p "${STATE_DIR}" && chmod 0700 "${STATE_DIR}"
  if ! [[ "${email}" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
    log "WARNING: ADMIN_EMAIL is not an e-mail address; using admin@example.com."
    email="admin@example.com"
  fi
  email="${email,,}"
  [[ "${name}" =~ ^[^[:cntrl:]]{1,100}$ ]] || name="Admin"

  wait_for_appsmith
  until state="$(empty_instance)" && [ -n "${state}" ]; do
    log "could not read the instance state; retrying in 15 s"
    sleep 15
  done

  if [ "${state}" = true ]; then
    local use_pw="${pw}"
    if ! password_ok "${pw}"; then
      use_pw="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
      touch "${LOCK_MARKER}"
      log "WARNING: ADMIN_PASSWORD must have 8-48 characters. The administrator ${email} is LOCKED with a random password. Set a valid ADMIN_PASSWORD and redeploy to unlock it."
    else
      rm -f "${LOCK_MARKER}"
    fi
    until create_admin "${email}" "${name}" "${use_pw}"; do
      log "creating the administrator failed; retrying in 30 s (the public domain stays unrouted meanwhile)"
      sleep 30
      [ "$(empty_instance)" = false ] && break
    done
    log "administrator ${email} created; sign-up for others is controlled by APPSMITH_SIGNUP_DISABLED."
  elif [ "${ADMIN_PASSWORD_RESET:-false}" = true ] || [ -e "${LOCK_MARKER}" ]; then
    if password_ok "${pw}"; then
      set_password "${email}" "${pw}" && rm -f "${LOCK_MARKER}"
    elif [ -e "${LOCK_MARKER}" ]; then
      log "WARNING: the administrator is still LOCKED: ADMIN_PASSWORD must have 8-48 characters."
    else
      log "WARNING: ADMIN_PASSWORD_RESET=true but ADMIN_PASSWORD must have 8-48 characters; password unchanged."
    fi
  fi
  touch "${READY_MARKER}"
}

main "$@"
