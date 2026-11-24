# Notice

## Upstream software

This repository contains Railway configuration and small scripts only. Appsmith is pulled at build time from its official container image; it is not stored in this repository.

| Software | License | Source (publisher) |
|---|---|---|
| Appsmith Community Edition v2.7.2 (with MongoDB, Redis, Caddy, Node.js and Java as shipped in the image) | Apache-2.0 (Appsmith CE); bundled components under their own licenses | `appsmith/appsmith-ce:v2.7.2@sha256:1f456089b75edec495c005f0e94858aa5c6d1408fcac5f7c1e2d85d69bd1592d` (Appsmith, Inc.) |

Appsmith source for the pinned release: https://github.com/appsmithorg/appsmith/tree/v2.7.2.

## Verified against

| What | Upstream file | Ref | Checked |
|---|---|---|---|
| Latest stable release | GitHub releases (`v2.7.2`, 2026-11-19), Docker Hub tags | v2.7.2 | 2026-11-24 |
| Entrypoint, `docker.env` generation, embedded MongoDB/Redis, supervisord | `deploy/docker/fs/opt/appsmith/entrypoint.sh`, `templates/docker.env.sh`, `Dockerfile` | v2.7.2 | 2026-11-24 |
| Caddy listen port from `PORT` (patched to `APPSMITH_HTTP_PORT`) | `deploy/docker/fs/opt/appsmith/caddy-reconfigure.mjs` | v2.7.2 | 2026-11-24 |
| First administrator (`POST /api/v1/users/super`, form fields, `Origin`), CSRF exemption header | `UserControllerCE.java`, `UserSignupCEImpl.java`, `CsrfConfigCE.java`, `Migration075SeedSuperUserSetupLock.java` | v2.7.2 | 2026-11-24 |

## Adapted code

| Our file | Source | Changes |
|---|---|---|
| `services/appsmith/railway-start.sh`, `railway-admin.sh`, `railway-healthz.mjs` | Written for this template | — |
| `caddy-reconfigure.mjs` (one-line `sed` at build time) | Appsmith (Apache-2.0) | Listen port read from `APPSMITH_HTTP_PORT` instead of `PORT` |

## Trademarks

"Appsmith" is a trademark of Appsmith, Inc.; "Railway", "MongoDB" and "Redis" belong to their respective owners. This is a community template and is not affiliated with or endorsed by them.
