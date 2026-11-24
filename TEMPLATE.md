# Appsmith 2.7 Community: composer spec

Listing name: **Appsmith 2.7 Community**
Description (66 chars): Low-code internal tools builder, admin pre-created, sign-up closed
Category: Other. Icon: `https://cdn.jsdelivr.net/gh/selfhst/icons/png/appsmith.png`
Repository: `baranberkay96/appsmith-railway` (this folder is the repo root).

## Services

| Service | Source | Public | Volume | Healthcheck |
|---|---|---|---|---|
| Appsmith | repo `/services/appsmith`: `FROM appsmith/appsmith-ce:v2.7.2@sha256:1f45…592d` + `railway-start.sh`, `railway-admin.sh`, `railway-healthz.mjs`; Caddy port patched to `APPSMITH_HTTP_PORT` | domain → 80 (Caddy) | `/appsmith-stacks` | `/healthz` on `PORT` 8081, 1200 s |

Pinned 2026-11-24: Appsmith CE v2.7.2 (2026-11-19). Image ≈1.1 GB compressed (under the 4 GB cap, 8.33).

## Design

- All-in-one image (upstream's recommended Docker deployment): embedded MongoDB and Redis on the same volume.
- First admin: Appsmith's migration `Migration10000_UpdateSuperUser` (runs on every boot) creates every e-mail in `APPSMITH_ADMIN_EMAILS` as a super user WITHOUT a password. Verified on the test deploy: with sign-up disabled, anyone could still sign up with that e-mail and become instance admin. `railway-admin.sh` waits for `/api/v1/health`, finds the user in the embedded MongoDB (`mongosh`), and sets its BCrypt password (`caddy hash-password`) before the healthcheck passes. If the instance has no user at all (admin e-mails emptied), it posts the setup form to `/api/v1/users/super` instead. Railway's healthcheck (`railway-healthz.mjs` on `PORT`) returns 200 only after this, so the public domain is never routed to an unclaimed instance. Unusable password → random password + lock marker; reset/unlock with a valid `ADMIN_PASSWORD` via the same hash update.
- `APPSMITH_SIGNUP_DISABLED=true`, `APPSMITH_ADMIN_EMAILS=${{ADMIN_EMAIL}}`, telemetry off, Java heap 1 GB.

## Improvements over market templates

Market (2026-11): `appsmith/appsmith-ee:latest` (Enterprise image, floating tag, healthcheck `/user/login`) ≈94 active; `appsmith-ce:v2.2` + external Redis ≈1 active.

- Community Edition (Apache-2.0) pinned by digest instead of the commercial EE image on `latest`.
- No open first-admin page; sign-up closed by default.
- Real readiness healthcheck instead of a static page path.

## Resources

Measured on Railway, test project, 2026-11-24 (Appsmith CE v2.7.2): 1.37 GB idle (backend, editor, RTS, MongoDB, Redis, Caddy). Estimate ≈ $15-20/month. Minimum plan: Hobby.

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month.

## Verification checklist

1. Service SUCCESS; `/api/v1/health` 200 on the public domain; log `[railway-admin] administrator … created`.
2. Login with `ADMIN_EMAIL`/`ADMIN_PASSWORD` via `/api/v1/login`; `/api/v1/users/me` shows the admin; `emptyInstance` false.
3. Sign-up of a new e-mail is refused.
4. Create a workspace/application through the API.
5. `ADMIN_PASSWORD=short` + reset → warning, healthy; valid password + reset → login with the new password.
6. Redeploy: apps and users persist.

## Open questions

- Appsmith's Git sync and AI features need outbound access to their providers; not tested.
