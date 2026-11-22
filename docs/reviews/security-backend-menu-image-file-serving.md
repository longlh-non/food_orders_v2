---
task: backend-menu-image-file-serving
status: passed
p0: 0
p1: 0
---

# Security review: backend-menu-image-file-serving

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-backend-menu-image-file-serving.md`.

- **Assets:** files outside the images folder (`orders.db` with customer names, `/etc`, `.env`), the event loop, and response headers.
- **Attacker input:** the `<file>` path segment and the HTTP method.
- **New capability:** reading files from disk by name.

## Round 1: passed. P0 0, P1 0, P2 0 (two optional notes)

Checked and clean:
- **Traversal:**
  - Only the decoded, validated name is joined to the folder. The ASCII-only regex allows no `/`, `\`, NUL, `%` or extra `.`, so no dot segments or lookalikes get through.
  - Decoding happens once (`%252e` → `%2e` → 400). A trailing newline fails, names are capped at 69 characters, and multi-segment paths never match the route.
- **Symlinks and TOCTOU:** `typeSync(followLinks: false)` rejects a link as the final component, and FIFOs, devices and folders aren't regular files. A symlinked `IMAGES_DIR` is owner-controlled. A swap between the check and the read needs write access to the folder, i.e. the owner.
- **Resources:** synchronous reads are capped at 1 MiB (checked before and after reading). That's acceptable at LAN scale.
- **Content type:** a fixed map keyed by the validated extension. SVG and HTML can't be served, and `nosniff` is set. A mislabelled file needs owner access and won't execute under `nosniff`.
- **Cascade:** only 404 or 405 fall through, to `OrdersApi`, which has routes under `/orders` only. A 400 stops the cascade.
- **Logging and output:** only the URL is logged. Bodies are fixed and never echo the input or paths.
- **Docs:** safe. No symlinks, no world-writable folder, no upload.

Optional notes (deferred, listed in the execute report):
- async reads or a concurrency cap;
- a docs line that the images folder must be writable by the owner only.

## Fix round 1 (code reviewer's P1, in this area)

`Uri.decodeComponent` throws `FormatException` for invalid UTF-8. The handler now catches it as well as `ArgumentError`, answering the fixed 400. shelf already refuses those URLs before any handler runs, and tests pin that.

## Re-review 1: passed. P0 0, P1 0, P2 0

The fix is confirmed: the decode failure returns 400 before any name check or path is built, so the file system is never touched.

## Gates

See `execute-backend-menu-image-file-serving.md`. `make check` exits 0.

## Needs owner confirmation in the real environment

`http://customer.local/api/images/..%2Forders.db` through Caddy (and nginx later). The proxies may normalise or reject the encoded path first, which is only more restrictive.
