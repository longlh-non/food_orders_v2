---
task: ci-build-artifacts
status: passed
p0: 0
p1: 0
---

# Review: ci-build-artifacts

## Gates

| Command | Exit code | Notes |
|---|---|---|
| YAML parse of `.github/workflows/ci.yml` (python3 `yaml`) | 0 | jobs `check`, `build`; `build.needs` = `check`; `build.permissions` = `contents: read` |
| `bash -n deploy/build.sh` | 0 | (implementer) |
| `dart compile exe backend/bin/server.dart` (original plan) | 255 | **fails**: sqlite3 build hook not supported by `dart compile` |
| `dart build cli -t bin/server.dart -o ../build/backend` in `backend/` (the step as now written) | 0 | run locally by the orchestrator; produces `bundle/bin/server`, `bundle/lib/libsqlite3.so` |
| `make format-check` | 0 | |
| `make check` | 2 | stops at `analyze`: the 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); no Dart changed in this card |

## Changed paths

`.github/workflows/ci.yml` (new `build` job; owner approved this file only), `docs/runbook-local.md` (sections 7 and 8), `docs/tasks/ci-build-artifacts.md` (deviation note, card was still active). Nothing else.

## Job as built

`build` runs after `check`, same triggers, `permissions: contents: read`, no secrets; pinned checkout and Flutter steps identical to `check`; `make bootstrap`; `bash deploy/build.sh`; backend compile check via `dart build cli` (bundle NOT uploaded, D5 open); credentials tripwire; two `actions/upload-artifact@cf430e03... # v7.0.2` uploads (`customer-web`, `restaurant-web`), 7 days, `if-no-files-found: error`. The upload-artifact SHA was resolved by the orchestrator from the public upstream repo with `git ls-remote` (lightweight tag `v7.0.2`).

## Findings

Code review: P0 0, P1 0, P2 5. Security review (`docs/reviews/security-ci-build-artifacts.md`): P0 0, P1 0, P2 3. Deferred P2 follow-ups:
1. Credentials check can pass vacuously if a build dir is missing (unreachable in practice: `build.sh` is `set -e` and uploads use `if-no-files-found: error`); add a `test -d` guard.
2. The check only looks for the variable names `STAFF_ID`/`STAFF_PASSWORD` (apps use the header names `X-Staff-Id`/`X-Staff-Password`) plus stray `.env*` files; reword step name, comment and runbook as a tripwire, not proof the artifact is secret-free.
3. Card text said `dart compile exe`: recorded as a deviation note in the card (done).
4. CI pins Flutter 3.47.7 vs local 3.50.1: `dart build cli` and `deploy/build.sh --output` unverified under the CI toolchain until the first run.
5. Same version skew for `deploy/build.sh`'s relative `--output`.
Follow-up for the owner/other cards: `deploy/food-orders-backend.service` install comment and `cd-server-deploy-script` must use `dart build cli`, and the unit must run `bundle/bin/server` with its `lib/` beside it. A future deploy must only consume artifacts from `push` to `main`, never PR runs.

## Unverified (owner acceptance)

The workflow has never run on GitHub: the job passing (incl. the sqlite3 hook download on the runner), `dart build cli` under Flutter 3.47.7, artifacts downloading and containing `index.html`; the three action SHAs (checkout, flutter-action, upload-artifact) should be checked on github.com; fork PRs getting no write token (GitHub default).

## Verdict

**Passed**, P0: 0, P1: 0.
