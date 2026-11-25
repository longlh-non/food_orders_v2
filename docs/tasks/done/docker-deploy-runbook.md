---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [docker-compose-stack, docker-data-backup]
---

# Docker step 5: the Docker section of docs/deploy.md

## Why

The Docker files are useless to the owner without a step-by-step guide, and `docs/deploy.md` currently says Docker is a non-goal and that `BIND_ADDRESS=0.0.0.0` must never be set. Those statements stay true for the systemd path, but need a pointer and one careful exception.

## Sources

The four earlier Docker cards and the files they created, `docs/deploy.md` (all sections), `docs/runbook-local.md` section 8, `docs/ci-cd-decisions.md`, `CLAUDE.md` "Safety policy".

## Goal

Documentation only; no code, no `deploy/**`.

1. **`docs/deploy.md`:** add a new final section before the acceptance table (name it "Running with Docker (alternative to sections 5 to 7)"), written in the same style (placeholders, "On your laptop" / "On the VM", "unverified until you do it"). It covers:
   - when to pick Docker vs the systemd path, and "pick one: both want ports 80 and 443";
   - installing Docker Engine from the official repository (key checked on the official page, no piped scripts), and the warning that **published Docker ports bypass `ufw`**, so only 80 and 443 may be published and `ufw status` does not prove port 3000 is closed;
   - folders and ownership for uid 10001, creating `/etc/food-orders/backend.env` and `caddy.env` (mode 600; names of the variables only, point to 5.5 and 5.6 for the rules), including the `$` in the bcrypt hash;
   - **`BIND_ADDRESS` in a container:** the image sets `0.0.0.0` inside the container; this is safe only because the backend service has no `ports:`. Never add one. This is the one exception to "never set `BIND_ADDRESS=0.0.0.0`";
   - first install: copy the source and web builds, `docker compose build`, `up -d`, the checks of section 8 adapted (including `curl` to port 3000 from another machine must fail);
   - a web-only release (rsync builds; no restart) and a backend release (backup first, `docker compose build backend`, `up -d backend`, rollback = rebuild the previous revision; the database is not rolled back, section 9.5 style);
   - backups: running `docker compose run --rm backup`, the cron line, the off-site pull, the restore rehearsal and a real restore (stop the backend container, restore the pair into the host folders, fix ownership to uid 10001, start);
   - adding photos and editing the menu with `sqlite3` on the host paths;
   - what is unverified (every command; the hardening options against the Dart bundle; Docker with ufw/Oracle iptables).
2. Edit line 33 of `docs/deploy.md` ("no Docker; Docker is a non-goal") and the "never add `BIND_ADDRESS=0.0.0.0`" sentence in section 2 so they say "for the systemd path" and point to the new section. Add Docker rows to the acceptance table (section 12), all "unverified".
3. **`docs/runbook-local.md` section 8 (Deploy status):** add one short pointer to the Docker section and the status "files written, not run".
4. **`docs/ci-cd-decisions.md`:** append the Docker decision record (DOCKER1 to DOCKER10 with the owner's answers once given, or "open" if not).

Optional, **only with the owner's explicit approval in the task** (CLAUDE.md edits need approval each time): a short mention in the `CLAUDE.md` Layout (`deploy/docker/`) and a one-line note under `BIND_ADDRESS` ("inside the Docker image it is `0.0.0.0`; the compose file never publishes port 3000"). If approval is not given, list it as a follow-up and do not edit.

## Non-goals

Editing `deploy/**`, `.github/**`, `Makefile`; rewriting the systemd sections; HOST1/HOST2 choices; the Docker CD cards; image upload.

## Tests written with the change

None (documentation). The executor checks every file name, path, variable name and command in the new section against the actual Docker files, and that no real secret, hostname or key appears.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Every command and path matches the files produced by the earlier cards | `code-reviewer` (review) |
| Section says port 3000 must never be published and explains the `ufw` bypass | `code-reviewer` (review) |
| Existing systemd sections still read correctly; the Docker exception is clearly scoped | `code-reviewer` (review) |
| No secrets or real hostnames; placeholders only | `code-reviewer` (review) |
| `make check` exit 0 | gate |
| Owner can follow the section on a fresh VM | **owner acceptance, "unverified" until done** |

## Environment limits

Nothing here was run. State that in the section and in the review report. Agents cannot run Docker or `sudo`.

Approvals: none for `docs/**`. `CLAUDE.md` edits only with explicit approval for this task.
