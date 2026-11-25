---
task: docker-deploy-runbook
status: passed
p0: 0
p1: 0
---

# Security review: docker-deploy-runbook

Reviewer: security-reviewer, run on the documentation change (the card has no `securityReview` field; the diff describes network exposure, so a review was added). No P0, no P1, four P2. Read-only; nothing run.

## Findings

1. P2 the source tree `/opt/food-orders-src` must stay root-owned (root cron builds from it), but `rsync -a` keeps the laptop uid after a release. **Fixed**: the three rsync lines in 11a now use `--chown=root:root`.
2. P2 `CLAUDE.md` firewall advice did not say that `ufw` does not guard Docker-published ports. **Fixed**: the approved `BIND_ADDRESS` sentence now adds that and points to `docs/deploy.md` 11a.2.
3. P2 the off-site backup folder had default permissions. **Fixed**: `install -d -m 700 ~/food-orders-backups` in 11a.
4. P2 `docker compose config --quiet` checks syntax only and does not show whether the `$2a$...` hash stayed intact. **Accepted**: a mangled hash fails closed (401 for everyone); the real login test is the check, and printing the config would reveal the hash.

## Checked and clean

Port 3000 is never published (no `ports:`/host networking on `backend`; only 80 and 443 on `caddy`; `network_mode: none` on `backup`); the `ufw` bypass is stated accurately and checked from another machine; the `BIND_ADDRESS` exception is scoped to the Docker image; secrets only via `env_file` to `/etc/food-orders/*.env` (mode 600, `sudoedit`), none in `environment:` or `-e`; the `docker inspect` exposure and `docker` group risk are documented; fake placeholders only (`CHANGE-ME`, `$2a$14$REPLACE_ME`); Docker Engine from the official apt repository with a fingerprint check and no `curl | sh`; data and backups folders 700 owned by 10001; restore removes stale `-wal`/`-shm`/`-journal` and fixes ownership; `rsync --delete` is limited to exact folders and the web copy is guarded by `test -f build/*/index.html`; rollback and restore text says the database is not rolled back.

## Needs confirmation in a real environment

`$2a$` survives `env_file`; `sqlite3 .backup` across the bind mount; Docker's iptables rules with `ufw` and Oracle's rules; hardening options against the Dart bundle; `caddy:2.6.2` gets no fixes (accepted, revisit 2027-03-01).
