# Appsmith Community Edition for Railway: the official all-in-one image (backend, editor,
# realtime server, MongoDB, Redis and Caddy under supervisord) plus:
#   - railway-admin.sh: creates the first administrator from Railway variables, so the
#     "create the first admin" page is never reachable from the internet,
#   - railway-healthz.mjs: Railway's healthcheck on PORT; it answers 200 only when Appsmith is
#     healthy AND the administrator exists, so the public domain is routed to a deployment
#     only after setup is done.
# Appsmith's Caddy reads PORT for its listen port; it is moved to APPSMITH_HTTP_PORT (80) so
# that PORT can carry the healthcheck.
#
# Pinned by tag and digest. To upgrade, change both to a newer release:
# https://hub.docker.com/r/appsmith/appsmith-ce/tags (release notes: https://github.com/appsmithorg/appsmith/releases)
FROM appsmith/appsmith-ce:v2.7.2@sha256:1f456089b75edec495c005f0e94858aa5c6d1408fcac5f7c1e2d85d69bd1592d

COPY --chmod=0755 railway-start.sh /opt/appsmith/railway-start.sh
COPY --chmod=0755 railway-admin.sh /opt/appsmith/railway-admin.sh
COPY --chmod=0644 railway-healthz.mjs /opt/appsmith/railway-healthz.mjs

RUN sed -i 's/process\.env\.PORT || 80/process.env.APPSMITH_HTTP_PORT || 80/' /opt/appsmith/caddy-reconfigure.mjs \
 && grep -q 'process.env.APPSMITH_HTTP_PORT || 80' /opt/appsmith/caddy-reconfigure.mjs \
 && ! grep -q 'process.env.PORT' /opt/appsmith/caddy-reconfigure.mjs \
 && bash -n /opt/appsmith/railway-start.sh \
 && bash -n /opt/appsmith/railway-admin.sh \
 && node --check /opt/appsmith/railway-healthz.mjs \
 && test -x /opt/caddy/caddy && command -v mongosh curl python3 >/dev/null

ENTRYPOINT ["/opt/appsmith/railway-start.sh"]
CMD ["/usr/bin/supervisord", "-n"]
