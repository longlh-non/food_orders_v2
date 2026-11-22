---
task: shared-menu-item-image-field
status: passed
p0: 0
p1: 0
---

# Security review: shared-menu-item-image-field

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-shared-menu-item-image-field.md`.

- **Asset:** the origin and path of any picture request the apps make.
- **Attacker input:** the `image` field of `GET /api/menu`. Only someone who can edit the database, or a compromised backend or proxy, controls it; `/menu` is read-only for clients.
- **Boundary:** server JSON → `MenuItem.image` → `OrderApiClient.imageUrlFor`.

## Round 1: passed. P0 0, P1 0, P2 2 (optional)

Checked and clean:
- **No off-origin or scheme URL:**
  - The only URL builder is `imageUrlFor`, which returns the fixed `/api/images/` + a name that passed the regex.
  - The regex excludes `:`, `/`, `\`, `%`, `?`, `#`, spaces, `..` and a leading dot or `-`. So `http:`, `//host`, `javascript:` and `data:` all fail (tested), and the result is always a single-segment, same-origin relative path.
- **Trailing newline:** Dart's `$` matches only at the end of the input, and `'x.png\n'` is tested. The regex is ASCII-only, so there are no Unicode lookalikes.
- **IMG3b (fail the load on a bad name):** this is only a lever for someone who can already write the database or tamper with responses, and they could break the menu anyway. Failing closed and loudly is the safer choice.
- **A later `Image.network`:** the relative URL resolves same-origin, so there's no cross-origin fetch, tracking pixel or SSRF. Always use `imageUrlFor`; never build the URL from `item.image` by hand.

P2 (deferred, see the execute report):
- The regex is duplicated across the shared and backend packages (invariant 4 forbids a shared import). Keep a "keep in sync" comment on both sides and, optionally, the same name list tested in both.
- `menuImageName` is public. That isn't exploitable, since the value is validated and the doc comment says "Never a URL".

## Gates

See `execute-shared-menu-item-image-field.md`. `make check` exits 0.

## Needs real-environment confirmation (later card)

`customer-menu-tile-shows-image`: check that Caddy routes `/api/images/*` to the backend with the prefix stripped, and look at the response headers.
