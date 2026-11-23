---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [deploy-production-config, deploy-demo-access-gate]
securityReview: required
---

# Deploy runbook: free always-on VM, step by step for the owner

**Docs note (2026-11-19):** when this card lands, update `docs/runbook-local.md` section 8 'Deploy (CD) status', and make `docs/deploy.md` and `docs/runbook-local.md` link to each other.

## Why

Agents cannot create cloud accounts or run `sudo`. Provisioning is the owner's job, so it needs a precise, copy-pasteable document. This card writes it and records the hosting decisions. Security review is required because the document tells the owner how to expose the app to the internet (firewall, ports, auth).

## Sources

`deploy/*` from the earlier cards, `CLAUDE.md` "Reverse proxy", "Safety policy", the hosting findings below (third-party sources as of 2026-11-09; the owner must confirm limits and prices on the official provider pages before relying on them).

## Goal

New `docs/deploy.md` (not CLAUDE.md; a one-line pointer in CLAUDE.md needs owner approval, so ask) containing:

1. The decision record: why a VM and not a PaaS free tier. Render free sleeps after 15 min idle and has no persistent disk (SQLite lost, SSE drops). Railway is a one-time trial. Fly.io has no free tier for new orgs. Koyeb free scales to zero and has no volume. Only always-free VMs give always-on + disk.
2. Provider steps for the chosen provider (HOST1): Oracle Cloud Always Free (idle instances can be reclaimed; keep light activity; card needed; pick home region carefully - for a Vietnam user a nearer Asia region such as Singapore may exist, but availability must be checked at signup) or Google Cloud e2-micro (US regions only, 1 GB RAM, static IP may cost extra). Instance creation, SSH key, opening ports 80/443 only (cloud firewall and `ufw`), port 3000 NOT open.
3. Server setup: install Caddy and Dart SDK (owner runs), create the service user and data dir, build the backend binary on the VM, install `deploy/food-orders-backend.service`, put the auth hash in the server-only environment file, enable and start.
4. Domain and DNS (HOST2): A records for `customer.` and `restaurant.` pointing at the VM IP; Caddy fetches certificates automatically once DNS resolves.
5. Release procedure: run `deploy/build.sh` locally, `rsync build/customer` and `build/restaurant` to the server, `systemctl reload caddy`; backend update procedure.
6. Backups and restore (HOST5), including a restore rehearsal.
7. Keep-alive note for Oracle idle reclamation, and what to do if the VM is lost (rebuild from this doc plus the latest backup).
8. A "known risks" section stating plainly: no real auth (see HOST3 outcome), free tiers can change or be withdrawn, single VM = no redundancy.

## Non-goals

Executing any step, Docker, CI/CD deploy, monitoring stack, real auth.

## Tests written with the change

None (documentation). Checked by review for commands that would be dangerous if copy-pasted (no `rm -rf` with variables, no `chmod 777`, no opening port 3000).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Commands accurate and safe, secrets never in the doc | `security-reviewer` + `code-reviewer` (review) |
| Doc consistent with `deploy/` files | `code-reviewer` (review) |
| Owner can follow it end to end on a fresh VM | owner acceptance: complete the runbook on the real VM - "unverified" until done |
| `https://<customer-domain>` opens on a phone over MOBILE DATA (not home wifi), asks for the shared password, order placed appears live on the restaurant site | owner acceptance in the real environment |
| Orders survive `sudo systemctl restart food-orders-backend` and a VM reboot | owner acceptance |
| Port 3000 unreachable from outside; 80 redirects to 443 | owner acceptance (`curl` from another network) |
| Backup file created and restore rehearsed | owner acceptance |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

Agents cannot verify any of the live behaviour. All provider facts are second-hand and dated; the owner confirms them on the official pricing pages (Oracle Always Free resources, Google Cloud Free Tier) before creating the account.

## Decided by the owner (2026-11-13)

- **HOST3 = A:** a shared Caddy `basic_auth` gate.
- **HOST5 = backups yes:** back up the database and the images folder, and rehearse a restore.
- **Still open:** HOST1 (provider, which also decides the CPU architecture, D5) and HOST2 (domain).

Recorded in `docs/ci-cd-decisions.md`.
