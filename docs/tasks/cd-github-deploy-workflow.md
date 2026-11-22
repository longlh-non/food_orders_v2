---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: [ci-build-artifacts, cd-server-deploy-script]
securityReview: required
---

# CD step 2: GitHub workflow that deploys a tagged release to the VM

**Docs note (2026-11-19):** when this card lands, update `docs/runbook-local.md` sections 7 'CI today' and 8 'Deploy (CD) status'.

## Why

With a tested build (`ci-build-artifacts`) and a safe server script (`cd-server-deploy-script`), the workflow only has to carry files to the VM and call the script. Keeping logic out of the workflow keeps secrets exposure small.

## BLOCKED on owner decisions

HOST1 to HOST3 (provider, domain, access gate) are not decided, and the GitHub remote must exist. This card cannot be fully specified until `docs/deploy.md` exists. Executor must stop and ask if it does not.

## Open decisions (owner), with recommendation

- D9 Trigger: recommend deploy on a version tag (`v*`), not on every push to main. A live restaurant should change when the owner decides, and a tag is a clear record of what is live. Alternative: every main push (faster, riskier, no pause).
- D10 Approval gate: recommend a GitHub Environment named `production` with the owner as required reviewer, so a tag waits for a click. Required reviewers on private repos can depend on the GitHub plan; the owner confirms. Alternative: no gate, tag is the approval.
- D11 Who holds secrets: recommend only the owner (repo admin) holds the SSH private key and host key as **environment secrets** of `production`, not repo-wide secrets, so a PR workflow cannot read them. Use a dedicated deploy key and a dedicated VM user that may run only the deploy script (restricted `authorized_keys` command, or `sudo` limited to `systemctl restart food-orders-backend` and `reload caddy`). No personal SSH key.
- D12 SSH: recommend pinning the server's host key in a secret or variable and using `StrictHostKeyChecking=yes`, instead of `ssh-keyscan` at run time. Needs no extra third-party action: plain `ssh`/`rsync` on the runner. Alternative: a marketplace deploy action (a new third-party dependency, owner approval, pin by SHA).
- D13 Server-only values: `STAFF_ID`, `STAFF_PASSWORD`, `ORDERS_DB`, `IMAGES_DIR`, the basic-auth hash stay in the VM environment file. CI never sees them.

## Goal

New `.github/workflows/deploy.yml`:

- `on: push: tags: ['v*']` (D9), plus optional `workflow_dispatch` for a manual redeploy.
- Reuses the build from `ci-build-artifacts` (same script; re-runs `make check` first or requires that the tagged commit's CI passed).
- Job uses `environment: production` (D10), `permissions: contents: read`, `concurrency` group `deploy` with `cancel-in-progress: false` (never cancel a deploy half way).
- Steps: build, upload release folder with `rsync` over SSH, run `deploy/deploy.sh` remotely, fail the job if it exits non-zero (rollback already happened on the server).
- Secrets only inside the deploy step's `env`, never echoed, SSH key file written with mode 600 and removed after.
- Does not trigger on `pull_request` and never runs for forks.

## Non-goals

Creating the VM or DNS, Docker, multiple environments (staging), notifications, auto-rollback of the database, changing the deploy script.

## Tests written with the change

None runnable. Optional `actionlint` (new tool; owner decides).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| No secret in the repo or in logs; secrets scoped to the `production` environment; deploy cannot run from a PR or a fork | `security-reviewer` (review) |
| Actions pinned by SHA, minimal permissions, no cancel mid-deploy | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Pushing tag `v0.0.1-test` asks for approval, deploys, health check passes, site opens | owner acceptance, "unverified" until done |
| A broken release rolls back and the job turns red | owner rehearsal, "unverified" until done |

## Environment limits

Agents cannot run Actions, reach the VM, or hold secrets. The owner adds the secrets in GitHub settings; the agent only names them in the card and the workflow.

## Decided by the owner (2026-11-13)

Every recommendation was accepted ("all recommended"): D1–D4 and D6–D13, HOST3 = A (shared Caddy `basic_auth`) and HOST5 = backups yes. The record, with reasons, is `docs/ci-cd-decisions.md`. Treat those as settled.

Still open: HOST1 (provider), D5 (which follows from HOST1) and HOST2 (domain). The GitHub remote exists (`origin` → `github.com/longlh-non/food_orders`, checked 2026-11-13). Edits to `.github/**` or `deploy/**` still need the owner's explicit approval when this card runs.
