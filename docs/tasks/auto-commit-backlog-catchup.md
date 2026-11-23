---
executor: task-executor
scopes: [docs]
workKinds: [planning, documentation]
blockedBy: [auto-commit-decisions]
---

# One-time plan: commit the existing uncommitted backlog

The working tree holds the finished work of many cards (backend, shared, customer, restaurant, CI, docs; deleted and renamed card files) and `git log` has one commit ("Move repository"). Automatic per-card commits (`auto-commit-contract-docs`, `auto-commit-permissions`) only make sense after this backlog is out of the way; otherwise the first automatic commit would either swallow it or be blocked by the "unrelated changes" stop rule.

**This card produces a written plan and a safe-staging checklist, and the owner runs it.** The agent does not commit here, and the card is done without any commit made by an agent. Owner approval is needed to touch any file outside `docs/tasks/`: this card edits none.

## Why per-card splitting is not offered

Files overlap (`backend/lib/orders_api.dart`, `backend/lib/database.dart`, `lib/shared/models/order.dart`, `CLAUDE.md`, `docs/runbook-local.md`, `lib/restaurant/pages/orders_page.dart`...). Their final text holds changes of several cards at once, and there are no per-card snapshots. Splitting with `git add -p` would mean guessing hunk ownership and would produce commits that don't build or don't pass tests. A commit that doesn't build is worse than one honest big commit.

## Goal

Produce the plan under "Plan" below as an appended section of this card (the executor fills in the real file lists from `git status --short`), then the owner runs it.

### Plan (default per AC3; adjust to the owner's answer)

1. **Prepare (owner):** stop the backend, run `make check`. Expected today: exit 2 from `make analyze` (known baseline); record the output. Resolve nothing else silently.
2. **Secrets and data check (executor lists, owner confirms):** run `git status --short --ignored` and `git ls-files` equivalents to confirm that none of these are tracked or about to be: `.env*`, `backend/data/**`, `build/`, `.dart_tool/`, `sample/*.xlsx`, `*.csv`, `*.xlsx`, `.claude/settings.local.json`, `.vscode/`, any file with a staff ID or password. Anything unexpected: stop, move or ignore it first (an edit to `.gitignore` is a root file needing a plain owner decision).
3. **Groups, in this order** (each is a separate commit, explicit paths, `git diff --cached --stat` before each):
   1. `chore(docs): archive finished task cards and reviews` - `docs/tasks/**` (deletes, renames, `done/`), `docs/reviews/**`, `docs/journey.md`.
   2. `feat(backend): accumulated backend work` - `backend/**` excluding `backend/data/`.
   3. `feat(shared): accumulated shared models and api` - `lib/shared/**`, with matching `test/**`.
   4. `feat(customer): accumulated customer app work` and `feat(restaurant): ...` - `lib/customer/**`, `lib/restaurant/**`, `lib/dev/**` with their tests.
   5. `chore(ci): CI and contract changes` - `.github/**`, `CLAUDE.md`, `docs/*.md`, `.claude/**` (not `settings.local.json`).
   Groups 2-4 won't each pass `make check` alone, because the code depends on each other. State that plainly in each commit body ("part of an import; builds only with the next commits"), or use the single-commit option below if the owner wants every commit to pass.
4. **Single-commit option:** `chore: import accumulated work` with all of the above. Simpler, honest, loses grouping.
5. **After:** `make check` again from a clean tree, `git status --short` empty, `git log --stat | head` read by the owner.
6. **Optional but separate:** pushing to a remote is the owner's decision and not part of this card.

### Overlap with cards that still sit in `docs/tasks/`

`cd-github-deploy-workflow`, `cd-server-deploy-script`, and the `*-l10n-*` cards are active, unfinished work. They go into group 1 as-is (they are not history yet); partial work from them in the tree, if any, is listed by the executor and goes with its area, flagged "in progress".

## Open decisions for the owner

- **CU1:** grouped commits (above) or the single import commit? Recommendation: single import commit if the owner values "every commit builds"; five grouped commits if the owner values readable history. Either is fine; do not try per-card.
- **CU2:** do the deleted active cards (`D docs/tasks/...`) go in group 1? Recommendation: yes.
- **CU3:** is it acceptable that this first commit contains the unreviewed-in-this-session state? The review reports under `docs/reviews/` hold the evidence for each card; this card does not re-review anything.

## Non-goals

No code or config edits, no agent commits, no push, no history rewriting, no cleanup of the working tree (`git clean`, `restore`, `reset` are denied).

## Tests written with the change

None (documentation and a checklist).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| The plan lists real paths per group from `git status --short`, with no path appearing in two groups | independent review comparing the plan to a fresh `git status --short` |
| The secrets and data check lists every item above and shows the result of the commands run | review report contains the command output summary |
| `make check` run before the catch-up, with the exit code recorded (expected 2 from the known analyze baseline) | gate run recorded in the review; any other failure is stopped and reported |
| The owner has run the commits and `git status --short` is empty afterward | **owner acceptance** (agents cannot run the commits; unverified until then) |

## Environment limits

- Agents cannot run `git add` / `git commit` today (blanket Bash ask, no allow). This card therefore stays a plan, and the owner (or an owner-approved session) runs the commits by hand.
- Once committed, the commits are local and only the owner can undo them. The plan should be read once in full before step 3.
- Whether the tree builds at each intermediate commit is not guaranteed (see group note above).
