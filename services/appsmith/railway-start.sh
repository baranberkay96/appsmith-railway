#!/bin/bash
# Appsmith on Railway: start the healthcheck server and the administrator bootstrap in the
# background, then hand over to the image's own entrypoint (supervisord with backend, editor,
# realtime server, MongoDB, Redis and Caddy).
set -uo pipefail

log() { printf '[railway-start] %s\n' "$*"; }

# PORT carries Railway's healthcheck; Appsmith's Caddy listens on APPSMITH_HTTP_PORT.
[[ "${APPSMITH_HTTP_PORT:-80}" =~ ^[0-9]{2,5}$ ]] || { log "WARNING: APPSMITH_HTTP_PORT='${APPSMITH_HTTP_PORT}' is not a port; using 80."; export APPSMITH_HTTP_PORT=80; }
export APPSMITH_HTTP_PORT="${APPSMITH_HTTP_PORT:-80}"
if ! [[ "${PORT:-}" =~ ^[0-9]{2,5}$ ]] || [ "${PORT}" = "${APPSMITH_HTTP_PORT}" ]; then
  log "WARNING: PORT='${PORT:-}' must be a port other than ${APPSMITH_HTTP_PORT}; using 8081 for the healthcheck."
  export PORT=8081
fi
# A custom domain makes Appsmith's Caddy request certificates itself; Railway terminates TLS.
if [ -n "${APPSMITH_CUSTOM_DOMAIN:-}" ]; then
  log "WARNING: APPSMITH_CUSTOM_DOMAIN is ignored on Railway (Railway serves HTTPS for custom domains)."
  unset APPSMITH_CUSTOM_DOMAIN
fi

mkdir -p /appsmith-stacks/.railway
chmod 0700 /appsmith-stacks/.railway

( while true; do node /opt/appsmith/railway-healthz.mjs; log "healthcheck server exited; restarting"; sleep 2; done ) &
/opt/appsmith/railway-admin.sh &

exec /opt/appsmith/entrypoint.sh "$@"
