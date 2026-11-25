---
task: docker-deploy-runbook
status: passed
p0: 0
p1: 0
---

# Review: docker-deploy-runbook

Changed: `docs/deploy.md` (new section 11a "Running with Docker (alternative to sections 5 to 7)", line 33 and the section 2 `BIND_ADDRESS` sentence scoped to the systemd path, six Docker rows in the acceptance table), `docs/runbook-local.md` section 8 pointer ("files written, not run"), `docs/ci-cd-decisions.md` (Docker decision record DOCKER1 to DOCKER10; HOST1/HOST2 still open), and two owner-approved edits for this task only: `CLAUDE.md` (a `deploy/docker/` Layout entry and one sentence at the `BIND_ADDRESS` text) and a comment-only edit of `deploy/docker/caddy.env.example`. No other `deploy/**`, `.github/**` or `Makefile` change.

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run after fixes |
| `make boundaries` | 0 | re-run after fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos, no Dart changed |

Nothing in the new section was run: no Docker, no `docker compose config`, no sudo.

## Findings (code-reviewer): P0 0, P1 0, P2 4

All Docker commands, paths, mounts, service names, variables and backup file names in 11a were checked against the real files and match. Fixed:
- cross-reference "(11a.5)" corrected to 11a.4 (where the no-`ports:` rule is explained);
- "2 and 5.8 say never set `BIND_ADDRESS=0.0.0.0`" corrected to "section 2 and the unit file";
- `sudo install ... /dev/null` now says "first time only" for `backend.env` and `caddy.env` (a re-run would empty the real file).

Deferred: the cron line (`docs/deploy.md` and the comment in `deploy/docker/compose.yaml`) has no `-T`; Compose v2 normally detects a missing terminal, so it is probably unnecessary, but if cron logs a TTY error add `-T` in both places together. Unverified.

## Security review: see `security-docker-deploy-runbook.md`.

## Unverified (owner acceptance)

Every command in 11a; that the `dart:3.14.0` tag exists and its Debian release matches `bookworm-slim`; hardening options against the Dart bundle, SQLite and Caddy 2.6.2; that `$` in the bcrypt hash survives `env_file`; `sqlite3 .backup` across the bind mount while the backend runs; Docker's firewall rules beside `ufw` and Oracle's `iptables`; browser behaviour behind the gate; whether rsync changes appear through the read-only web mounts without a restart; the owner can follow 11a on a fresh VM.
