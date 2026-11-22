---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: [deploy-production-config, deploy-runbook]
securityReview: required
---

# CD step 1: a server-side deploy script with backup, health check and rollback

**Docs note (2026-11-19):** when this card lands, update `docs/runbook-local.md` sections 8 'Deploy (CD) status' and 3 'Database' (backup and rollback on the server).

## Why

Deployment must be safe by hand before it is automated. The script is the one thing a later GitHub workflow calls, and the owner can run it without GitHub. It lives on the VM, so no secret ever needs to enter CI for this logic.

Schema steps run on backend start (CLAUDE.md), and CLAUDE.md requires a dated backup before starting a backend with new schema steps. The script must therefore always back up first.

## Sources

`deploy/*` (Caddyfile, systemd unit, `backup.sh`), `docs/deploy.md` from `deploy-runbook`, `CLAUDE.md` "Backend" -> "Storage", "Safety policy".

## BLOCKED on owner decisions

- HOST1 (provider) and the VM's CPU architecture, HOST2 (domain), HOST5 (backups yes/no). Without them the paths, user and restart commands are guesses. Executor must not start until `docs/deploy.md` records them.

## Open decisions (owner), with recommendation

- D7 Release layout: recommend `releases/<timestamp>/` folders plus a `current` symlink for the web builds and the backend binary. Rollback = point the symlink back and restart. Simple, no extra tool. Alternative: overwrite in place (no rollback without a rebuild).
- D8 Health check target: there is no `/health` route. Recommend checking `GET http://127.0.0.1:3000/menu` on the VM (expects 200, bypasses Caddy and basic auth, no backend change). Alternative: add a `/health` route, which is a contract change (table first, own card).

## Goal

`deploy/deploy.sh` (run on the VM, by the owner or by CD over SSH), taking the path of an uploaded release folder:

1. Make a dated backup of the database and images with `deploy/backup.sh` (`sqlite3 .backup`, not `cp`, so it is safe while running). Abort if the backup fails.
2. Move the release into `releases/`, switch `current`, restart the backend service, reload Caddy.
3. Poll the health check for up to N seconds. On failure, switch `current` back, restart, and exit non-zero.
4. Keep the last N releases, delete older ones (no `rm -rf` on unchecked variables; paths come from fixed constants).
5. Never touches `ORDERS_DB`, `IMAGES_DIR`, the staff ID and password (`STAFF_ID`, `STAFF_PASSWORD`) or the auth hash; those stay in the server-only environment file.

Note the limit in the doc: rollback restores the old binary but NOT the old database. If a new schema step already ran, the old binary may not understand it; restoring means the pre-deploy backup, done by hand per the runbook.

## Non-goals

GitHub workflow, secrets, creating the server, `sudo` by agents (script uses `sudo systemctl` lines for the owner; agents print, never run), Docker, blue/green, real health endpoint.

## Tests written with the change

None runnable by agents. `code-reviewer` does a shellcheck-style read (`set -euo pipefail`, quoting). Owner rehearses on the VM, including a deliberately failing release to see the rollback.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Backup always runs first and aborts on failure | `code-reviewer` (review) + owner rehearsal |
| Failed health check rolls back automatically | owner rehearsal, "unverified" until done |
| No secret or real hostname committed; no unsafe `rm` | `security-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

Agents cannot reach the VM. Everything live is owner acceptance.

## Decided by the owner (2026-11-13)

Every recommendation was accepted ("all recommended"): D1–D4 and D6–D13, HOST3 = A (shared Caddy `basic_auth`) and HOST5 = backups yes. The record, with reasons, is `docs/ci-cd-decisions.md`. Treat those as settled.

Still open: HOST1 (provider), D5 (which follows from HOST1) and HOST2 (domain). The GitHub remote exists (`origin` → `github.com/longlh-non/food_orders`, checked 2026-11-13). Edits to `.github/**` or `deploy/**` still need the owner's explicit approval when this card runs.
