# Prefer supported paths

Production code uses public, documented APIs of Flutter, Dart, shelf, and the browser.

- If something isn't supported, say so, degrade gracefully, or ask the owner for a product decision.
- Private APIs, reflection into internals, patching third-party packages, or relying on undocumented behaviour need the risk explained and the owner's explicit OK first.
- A spike may prove feasibility; the experimental workaround doesn't automatically become the production solution.
- Example already in this repo: SSE uses `request.hijack()` because shelf swallowed a streamed body. `hijack` is a public shelf API and the reason is written down in `CLAUDE.md` — that's the bar for any similar workaround.

When blocked, describe exactly what the official API can and can't do. Never silently ship different product behaviour to get a task done.
