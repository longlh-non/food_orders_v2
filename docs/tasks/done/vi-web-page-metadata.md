---
executor: task-executor
scopes: [shared]
workKinds: [flutter, documentation]
blockedBy: []
---

# Vietnamese browser-tab title and page metadata

## Why

The browser tab shows `food_orders` and the manifest says "A new Flutter project." These are visible to users (tab title, iOS home-screen name). Small and independent of the widget cards.

## Sources

`web/index.html` (`<title>`, `description` meta, `apple-mobile-web-app-title`, `<html lang>` if present), `web/manifest.json` (`name`, `short_name`, `description`).

## Goal

Replace those values with Vietnamese (or a neutral brand name if the owner prefers, VI6) and set the page language to `vi`. Note that both apps share one `web/` folder, so both get the same tab title; per-app titles are out of scope.

## Non-goals

No icons, no per-app web builds, no widget changes.

## Tests written with the change

None practical (static files). `flutter test` must stay green.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Values changed, JSON still valid | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Tab title and iPhone "Add to Home Screen" name show the new text | owner acceptance in browser and phone - "unverified" until done |

## Environment limits

Agents cannot view the browser tab or the iOS home screen.
