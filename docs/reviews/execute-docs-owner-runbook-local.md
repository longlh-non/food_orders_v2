---
task: docs-owner-runbook-local
status: passed
p0: 0
p1: 0
---

# Review: docs-owner-runbook-local

Independent reviewer: `code-reviewer` (read-only). No security review: documentation only, no config or code changed. The card has no `securityReview`.

## Candidate

- **`docs/runbook-local.md` (new), the owner's runbook. Ten sections:**
  1. start everything;
  2. restart and reload ("I changed X → do Y");
  3. database (location, schema version 6, backup, restore, menu and pictures, a full order store);
  4. staff token;
  5. proxy, local names and phones;
  6. checks (`make` targets);
  7. CI today;
  8. deploy status;
  9. configuration reference (environment variables, files, ports);
  10. known gaps.
- **Five cards got one "Docs note (2026-11-19)" line each,** telling them to update the runbook when they land: `ci-dependabot-and-triggers`, `ci-build-artifacts`, `cd-server-deploy-script`, `cd-github-deploy-workflow`, `deploy-runbook`. `deploy-runbook` also links the two docs.
- `CLAUDE.md` is not edited (see the pointer suggestion below).

Owner decisions (2026-11-19): `docs/runbook-local.md`; a `CLAUDE.md` pointer line with the owner's OK; English; include restore; no separate CI/CD card.

## Evidence gathered by the executor

- **Flutter:** `flutter --version` gives Flutter 3.47.7 stable. `flutter run --help` says nothing web-specific about hot reload.
- **What the live `flutter run -d web-server` log prints:**
  - the key commands "r Hot reload", "R Hot restart", "q Quit";
  - the warning "The web-server device requires the Dart Debug Chrome extension for debugging".
- **So the runbook:** lists `r`/`R`/`q`, marks "reach a plain tab without the extension" as unverified, and recommends `R` + hard refresh, else `q` and restart.
- **Code facts used:**
  - the Makefile targets;
  - `database.dart` ends at `userVersion = 6`;
  - `staff_token.dart` minimum is 16;
  - `git remote -v` shows origin `https://github.com/longlh-non/food_orders.git`;
  - `ci.yml` runs on `push` and `pull_request`.

## Round 1: passed. P0 0, P1 0, P2 3

The reviewer checked every environment variable, default, startup line, staff route, status code, order limit, database step, backup and restore command, Makefile target, proxy route and limit, port, UI string, CI trigger and card slug against the code. All were OK.

There are no secrets and no dangerous commands, and no file is referenced that doesn't exist (`docs/deploy.md` only as "will get"). The restore keeps the current file first.

- **P2-1:** the picture-name rule was paraphrased loosely (it missed digits and the 64-character limit; "under 1 MiB" should be "at most"). **Fixed:** the exact rule, with a pointer to `CLAUDE.md`.
- **P2-2:** the clean-up `DELETE` hard-codes a date without saying to change it. **Fixed:** "change the date".
- **P2-3 (optional):** say the database has no `-wal`/`-shm` files, so copying one file restores it. Not added; noted here.
- **Also found by the reviewer:** the git log shows a second commit. **Fixed:** section 7 now says two commits are pushed (`de44cc3` "App demo 1st version"; `git status -sb` shows `main...origin/main`). Later work is uncommitted.

## Suggested `CLAUDE.md` pointer (needs the owner's OK; not applied)

After the line "Tests: `flutter test`. Analyze: `flutter analyze`." under "Running":

> Owner's step-by-step tasks (start, restart, back up, restore, staff token, checks): see `docs/runbook-local.md`.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make check` (after the doc was written; 303 app + 306 backend tests) | 0 |
| `make check` (after the fixes, final candidate) | 0 |

## Unverified (owner acceptance)

- Following the doc from scratch: start, restart, back up and restore on the real database.
- The proxy and mDNS steps (need `sudo`).
- Whether `r`/`R` reach a plain browser tab on `-d web-server`.

## After archiving (2026-11-19)

The owner approved the `CLAUDE.md` pointer line. It's added under "Running", after the Tests/Analyze line, word for word as suggested above.
