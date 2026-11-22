---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: []
---

# Owner runbook: every manual task in one place (`docs/runbook-local.md`)

## Why

The owner is new to Flutter and does many things by hand: start and restart the apps and the backend, back up and upgrade the database, set the staff token, reload the proxy, run checks. The facts are scattered over `CLAUDE.md`, `docs/ci-cd-decisions.md`, `docs/journey.md`, the Makefile, `dev/`, `.github/workflows/ci.yml` and the deploy/cd/ci cards. This card writes one owner-facing document. It documents only; it changes no code or config.

## Sources (read first, then verify every command against them)

`CLAUDE.md` (Running, Local domains, Reverse proxy, Backend: Run it / Storage / Editing the menu / body limit / staff token, Mobile access, Verification, Known limitations), `backend/bin/server.dart`, `backend/lib/database.dart`, `Makefile`, `dev/Caddyfile`, `dev/nginx.conf`, `dev/mdns-publish.sh`, `dev/food-orders-mdns@.service`, `.github/workflows/ci.yml`, `docs/ci-cd-decisions.md`, and the cards `deploy-*`, `cd-*`, `ci-*`.

## Goal

New file `docs/runbook-local.md` (name chosen so it does not clash with the planned `docs/deploy.md` from `deploy-runbook`; that one is for the hosted VM, this one is for the owner's own machine plus a status pointer). English, plain words, copy-paste commands, one or two lines of "why" per section. Sections:

1. **Start everything** - four processes in order: backend, customer app (`flutter run -t lib/customer/main.dart -d web-server --web-hostname=0.0.0.0 --web-port=8080`), restaurant app (same, port 8081), proxy. Include the `dev/demo.dart` option on 8082. Backend with the staff token: `read -rs STAFF_TOKEN && export STAFF_TOKEN && dart run bin/server.dart` (run from `backend/`, `dart pub get` once).
2. **Restart / reload each part** - a small table "I changed X, so I do Y":
   - Flutter app: `r` = hot reload, `R` = hot restart in the `flutter run` terminal; `q` quits. Then a browser hard refresh (Ctrl+Shift+R) to pick up a restart. **State accurately what `-d web-server` supports in the installed Flutter (3.47).** The owner's note: hot reload is not supported on web with `web-server`. The executor must check `flutter run --help` and the Flutter docs for this version and write what is true. If it cannot be confirmed, write "unverified" next to that line. Also explain: the manifest is not served in run mode ("manifest not generated in run mode"), it only applies to `flutter build web`.
   - Backend: no hot reload; Ctrl+C and start again. Always restart after backend code changes (a stale process once caused 400s).
   - Proxy: `sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy` (nginx alternative from `CLAUDE.md`). Note the 64 KB body limit lives in the proxy config, so editing it is a proxy reload.
   - mDNS after changing wifi: `sudo systemctl restart 'food-orders-mdns@*'`.
   - "After pulling or changing code": Flutter-only, backend-only, proxy-only, and `flutter pub get` / `dart pub get` when `pubspec.yaml` changed (`make bootstrap`).
3. **Database** - location, `ORDERS_DB`, `IMAGES_DIR`, pictures in `backend/data/images/`. Backup (dated `cp`, and the `sqlite3 ".backup"` live variant), when a backup is required (before starting a backend with a new schema step), **restore** (stop backend, copy the dated file back; also images folder), schema upgrade (steps numbered with `PRAGMA user_version`; the database is at version 6 now, executor verifies the number in `backend/lib/database.dart`; a step never edited once shipped; failed step rolls back), menu and picture edits with the `sqlite3` CLI (`sudo apt install sqlite3`; link to or copy the short examples from `CLAUDE.md`), what to do when the order store is full (find the exact behaviour in `orders_api.dart` and `CLAUDE.md` and describe the owner's action; month export if it exists by then), and "never delete the file to re-seed".
4. **Staff token** - what it is, that without `STAFF_TOKEN` (or shorter than the minimum) staff routes answer 403, how to set it without leaving it in shell history, never write it into a file in the repo. Take the minimum length from `staff_token.dart`.
5. **Proxy and mDNS** - Caddy as a service (do not also run `caddy run`), the nginx foreground alternative, `/etc/hosts` line, the backend binds `127.0.0.1:3000` by default and `BIND_ADDRESS` overrides it, ufw port 80, iOS check with `avahi-resolve`.
6. **Checks** - every `make` target in one line each; `make check` before committing; `make hooks-install` / `hooks-uninstall` for the opt-in format hook; `make format` is the only one that rewrites files. Mention the backend tests need network on the first run.
7. **CI today** - `.github/workflows/ci.yml` runs `make check` on push and PR. The GitHub remote is `origin` (github.com/longlh-non/food_orders); executor confirms with `git remote -v` output the owner can see, or says "unverified". State plainly that only the initial commit is pushed and later work is uncommitted (as of 2026-11-19, say "at the time of writing"), so CI has not seen it. Agents never commit unless asked.
8. **CD and deploy status** - not built. List the pending cards with one line each and pointers: `deploy-production-config`, `deploy-demo-access-gate`, `deploy-runbook`, `ci-dependabot-and-triggers`, `ci-build-artifacts`, `cd-server-deploy-script`, `cd-github-deploy-workflow`; hosting (HOST1/HOST2) still open. Point to `docs/ci-cd-decisions.md`.
9. **Configuration reference** - one table each: env vars (`ORDERS_DB`, `IMAGES_DIR`, `STAFF_TOKEN`, `BIND_ADDRESS`; default and effect; empty counts as unset), files and folders (`backend/data/orders.db`, `backend/data/images/`, `dev/Caddyfile`, `dev/nginx.conf`, `/etc/caddy/Caddyfile`), ports (3000 backend, 8080 customer, 8081 restaurant, 8082 demo, 80 proxy), URLs.
10. **Known gaps** - things the doc cannot verify (see Environment limits).

Rules for the text: never format a price by hand; no secrets or real tokens, only placeholders; no `rm -rf` with variables, no `chmod 777`; do not tell agents or the owner to run anything from `deploy/` that does not exist yet.

**Also in this card (small edit to five other cards):** add one "Docs note" line under the title of each of `ci-dependabot-and-triggers`, `ci-build-artifacts`, `cd-server-deploy-script`, `cd-github-deploy-workflow` and `deploy-runbook` (all in `docs/tasks/`): "when this card lands, update `docs/runbook-local.md` sections 'CI today', 'CD and deploy status' (and 'Database' for the deploy script)". For `deploy-runbook`, also say the two docs link to each other. Task cards are the only other thing this card may edit.

## Non-goals

- Editing `CLAUDE.md`, `Makefile`, `dev/**` or `.github/**` (all need explicit approval).
- Deploy/VM instructions (that is `deploy-runbook` -> `docs/deploy.md`).
- Moving or deleting existing sections elsewhere.
- Any code.

## CLAUDE.md relationship (recommendation, needs owner approval)

Keep `CLAUDE.md` as the agents' contract and the API/rules reference. Add one pointer line near "Running", for example "Owner's step-by-step tasks (start, restart, backup, token, checks): `docs/runbook-local.md`". Do not move or shorten the existing sections in this card; that removes information agents rely on and can be done later if the two drift. This card does not touch `CLAUDE.md`: the executor writes the exact pointer line into the review report as a suggestion, and the owner approves or applies it.

To avoid two copies drifting, the runbook should give commands and short explanations, and for long reference material (menu `sqlite3` examples, order rules, SSE note) link to `CLAUDE.md` instead of copying.

## Tests written with the change

None (documentation).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Every command and env var matches `server.dart`, `database.dart`, `Makefile`, `dev/*`, `ci.yml`, `CLAUDE.md` | `code-reviewer`, listing each checked command |
| Flutter `-d web-server` reload/restart statement is accurate for the installed version, or marked "unverified" | `code-reviewer` against `flutter run --help` output / Flutter docs recorded by the executor |
| Facts from this card (127.0.0.1 bind, schema version, token 403, 64 KB in proxy, restore steps) present and correct | `code-reviewer` |
| No secrets, no dangerous copy-paste commands, no reference to files that do not exist | `code-reviewer` |
| Only `docs/runbook-local.md`, the five one-line card notes and this card's review changed | `git status` check in review |
| `make check` green (docs only) | `make check` exit 0 |
| Owner can follow the doc from scratch and start, restart, back up and restore | owner acceptance in the real environment: "unverified" until done |

## Environment limits

Agents cannot run `sudo`, Caddy, systemd, mDNS or a browser, and cannot test a restore on the owner's real database. Hot reload behaviour on web depends on the Flutter version; verify with `flutter --version` and `flutter run --help` (the executor may ask the owner to run them, since every shell command asks), otherwise "unverified".

## Decided by the owner (2026-11-19)

Every recommendation was accepted:
1. **File:** `docs/runbook-local.md`.
2. **`CLAUDE.md`:** gets one pointer line near "Running", and its sections stay. The executor asks the owner before adding the line, per task.
3. **Language:** English.
4. **Restore:** include the restore procedure; it stays unverified on the real database until the owner tries it.
5. **No separate CI/CD card:** the later CI/CD and deploy cards keep sections 7–8 current. This card adds a one-line note to each of them.
