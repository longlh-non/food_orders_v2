---
description: Independent read-only security review of a task, diff, or pasted input — trust boundaries, input parsing, network exposure, dependencies, agent permissions.
argument-hint: "<docs/tasks/<slug>.md | scope-name> [git range | working-tree]"
---

Run `security-reviewer` on `$ARGUMENTS`. The calling workflow may run non-destructive gates and write the report; the reviewer only reads files and raw evidence, never runs commands, never edits.

## Modes

- **Task gate:** an active card in `docs/tasks/` (reject `done/`, symlinks, subfolders). Needs a git range, working tree, or file list — if none can be determined, stop. Write `docs/reviews/security-<slug>.md` with frontmatter `task`, `status`, `p0`, `p1`, and `reviewedFiles` (the files actually reviewed). If any reviewed file changes before the card is archived, re-review.
- **Free review:** pasted code, a design, or a threat model. Answer in chat; only write `docs/reviews/security-<scope>.md` if the owner asks, and never as a task gate.

## Rules

1. First pass is independent: don't give the reviewer any other reviewer's conclusions.
2. If analyze/tests/build already fail, report that plainly — a security review doesn't paper over a broken gate.
3. Each finding: severity, asset, attacker-controlled entry point, path to the dangerous operation or data, `file:line`, impact, minimal fix. No concrete path → not a finding.
4. Known accepted risks (no auth; LAN-reachable via mDNS on port 80) are listed as context, not re-raised as new findings — unless the change makes them worse.

When fixes are needed, wait for `/fix-review-findings <report>` — or, inside `/execute-tasks`, use its existing authorisation and 3-round limit.
