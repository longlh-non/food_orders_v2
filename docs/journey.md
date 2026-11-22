# food_orders — build journey

A chronological record of how this project was built in one session, including
the decisions, the dead ends, and the fixes. If `CLAUDE.md` is the "map of the
territory as it stands now," this is the "logbook of how we got here."

Written for a Flutter beginner coming back to the repo after a break (or for a
future AI session continuing the work). Each step says **what**, **why**, and
links to the files that changed.

---

## 1. Installing Flutter

Needed to pick between the snap package (sandboxed, breaks `flutter run` web
dev server) and the official tarball (lives in `~/development/flutter`,
owned by the user). Went with the tarball.

- Downloaded Flutter 3.47.7 stable (Linux x64) to `~/development/flutter`.
- Added `~/development/flutter/bin` to `PATH` in `~/.bashrc`.
- `flutter doctor` showed Chrome ✓, Android toolchain ✗ (expected — we're
  web-only), Linux desktop ✓.
- VS Code already had the Dart-Code.flutter extension installed.

**Takeaway:** Flutter's `web-server` device needs the real binary on PATH,
not snap. The ~1.5 GB tarball is a one-time cost.

---

## 2. Scaffolding a two-entry-point project

The product has two apps (customer-facing and restaurant-facing) that will
later be deployed to separate domains. Decision: **one Flutter project with
two `main.dart` files**, not two projects. Rationale: shared models, API
client, auth, theming — avoid duplication; a monorepo is premature.

Layout chosen:

```
lib/
├── shared/       # imported by both apps — never cross-import customer<->restaurant
├── customer/
│   ├── main.dart        # entry point
│   ├── state/           # Cart, MyOrders
│   └── pages/
├── restaurant/
│   ├── main.dart
│   └── pages/
└── dev/
    └── demo.dart        # dev-only split view
```

Run each with `-t`:
```bash
flutter run -t lib/customer/main.dart -d chrome --web-port=8080
flutter run -t lib/restaurant/main.dart -d chrome --web-port=8081
```

Also added `.vscode/launch.json` so F5 → pick one works. First smoke-run of
the counter demo in Chrome confirmed the toolchain.

**Takeaway:** Flutter's `-t` flag + VS Code launch configs = cheapest viable
multi-app setup.

---

## 3. The order flow

Built the minimum ordering loop end-to-end, with shared state via a
`ChangeNotifier` singleton. No backend yet — the repository was in-memory.

Files:
- `lib/shared/models/order.dart` — Order, OrderItem, OrderStatus
- `lib/shared/models/menu_item.dart` + `data/sample_menu.dart` — hardcoded menu
- `lib/shared/api/order_repository.dart` — singleton holding a List<Order>
- `lib/customer/state/cart.dart` — ChangeNotifier for in-progress cart
- `lib/customer/pages/menu_page.dart` + `cart_page.dart`
- `lib/restaurant/pages/orders_page.dart`
- `lib/dev/demo.dart` — split-view with shared repo (one process, two UIs
  side-by-side)

The state-management choice was **plain `ChangeNotifier` + `ListenableBuilder`**
— no Provider/Riverpod/Bloc. For a prototype at this scale that's enough.

**Dead end:** First version of `MenuPage._MenuItemCard` put price + "Add"
button in a Column inside ListTile.trailing. The trailing slot is
height-capped at 56px and the Column overflowed. Fix: price inline with the
title text; trailing = button only.

**Takeaway:** `ListTile.trailing` is for a single widget. For a two-piece
trailing area, use a `Row` or put one piece in `title` / `subtitle`.

---

## 4. Local domains: customer.local / restaurant.local

Rolling URL by port (`localhost:8080`, `:8081`) felt bad even for dev. Added
hostname entries to `/etc/hosts` and bound the Flutter dev servers to all
interfaces so the custom hostnames reach them.

```bash
sudo tee -a /etc/hosts <<<"127.0.0.1  customer.local  restaurant.local"
flutter run -t lib/customer/main.dart -d chrome --web-hostname=0.0.0.0 --web-port=8080
```

Visiting `http://customer.local:8080` now worked. But the port suffix still
looked bad.

---

## 5. Reverse proxy with Caddy

To drop the port, we needed something on port 80 that routes by `Host:`
header. Chose Caddy over nginx for local dev: 4-line config, no fiddling.
Config in `dev/Caddyfile`:

```
http://customer.local {
    handle_path /api/* { reverse_proxy localhost:3000 }
    reverse_proxy localhost:8080
}
http://restaurant.local {
    handle_path /api/* { reverse_proxy localhost:3000 }
    reverse_proxy localhost:8081
}
```

(The `/api/*` routing came later — see step 7.)

Installation gotcha: `apt install caddy` auto-starts a systemd service that
reads `/etc/caddy/Caddyfile` (NOT our `dev/Caddyfile`). The workflow became:
edit `dev/Caddyfile` → `sudo cp dev/Caddyfile /etc/caddy/Caddyfile` → `sudo
systemctl reload caddy`.

Also wrote `dev/nginx.conf` for a later migration (user plans to move to
nginx). Documented the Caddy↔nginx trade-offs in `CLAUDE.md`:
- Caddy: automatic HTTPS, trivial config, modern defaults.
- nginx: ubiquity, fine-grained control, non-HTTP (TCP/UDP) proxying,
  ops team familiarity, battle-tested at scale.

**Takeaway:** For local dev, Caddy wins on effort. For production, use what
the rest of your stack and ops team already run — usually nginx.

---

## 6. Mobile access via mDNS (Avahi)

User wanted to open `customer.local` on their iPhone. The laptop's
`/etc/hosts` only resolves hostnames locally — it doesn't advertise them.

For `.local` hostnames, the native resolution system is **mDNS/Bonjour**.
iOS has it built in. Android Chrome's `.local` support is spotty (not
reliable until Chrome 90+).

Setup:
```bash
sudo apt install -y avahi-utils          # provides avahi-publish
sudo ufw allow 80/tcp                     # open firewall for phone traffic
```

Then a systemd template unit `dev/food-orders-mdns@.service` runs
`avahi-publish -a -R <hostname> <ip>` for each alias, pulling the current
LAN IP at runtime from `dev/mdns-publish.sh`. Enabled instances:

```bash
sudo systemctl enable --now 'food-orders-mdns@customer.local' \
                             'food-orders-mdns@restaurant.local'
```

iPhone Safari then resolved `http://customer.local` → laptop's LAN IP →
Caddy on :80 → Flutter dev server. Worked.

**Gotcha caught later:** The published IP is read once at service start.
Switching wifi networks changes the LAN IP but the services keep publishing
the old one. Fix: `sudo systemctl restart 'food-orders-mdns@*'` after
network changes. Scripted IP-detection also filters out `docker|br-|veth`
interfaces so docker's bridge IP never wins.

---

## 7. Backend: Dart `shelf` + Server-Sent Events

The two separate apps don't share state — each is its own browser process
with its own `OrderRepository.instance`. A real backend was needed.

Built a Dart `shelf` server at `backend/bin/server.dart`:

| Method | Path | Purpose |
|---|---|---|
| GET | `/orders` | list all orders |
| POST | `/orders` | place a new order |
| PATCH | `/orders/{id}` | update status |
| GET | `/orders/stream` | SSE stream of order events |

Flutter side:
- Added `http: ^1.2.2` to `pubspec.yaml`.
- Added `toJson`/`fromJson` to `Order` and `OrderItem`.
- Rewrote `order_repository.dart` as an `HTTP + SSE` client with the same
  `ChangeNotifier` surface. **No page widgets had to change.**
- New `order_api_client.dart` wraps the HTTP calls and parses SSE line
  format (`data: <json>\n\n`), with 2-second reconnect on drop.
- Both entry points now call `OrderRepository.instance.init()` before
  `runApp` (fire-and-forget).

Caddy got `handle_path /api/*` routing on both hostnames — Flutter calls to
`/api/orders` are same-origin, no CORS needed. Reload Caddy after edit:
`sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy`.

### 7a. The SSE bug and the hijack fix

Initial SSE handler used `Response.ok(controller.stream, headers: ...)`.
Headers reached the browser fine (chunked encoding, right content-type),
but the response body was silently swallowed — zero bytes delivered,
connection stayed open, no events ever arrived. Reproducible with raw
curl direct to the backend, so not a Caddy issue.

Fix: switched to `request.hijack((channel) { ... })`, which gives direct
access to the socket. We write the HTTP response header lines manually and
push `data: ...\n\n` chunks straight to `channel.sink`.

Trade-off: hijacked responses skip shelf middleware. CORS header is
embedded manually in the hijacked response; `logRequests` only sees the GET
+ a trivial duration (open-connection time isn't tracked).

**Takeaway:** If you ever port the backend to a different language, SSE
will Just Work there — this specifically is a shelf quirk.

---

## 8. In-app notifications

Added real-time feedback on both sides when state changes.

### Restaurant side (`restaurant/pages/orders_page.dart`)
- Converted `OrdersPage` to `StatefulWidget` with a `_seenIds` set.
- Each repo-change tick, diff: any new id with status `pending` → fire a
  snackbar with an "Accept" action + play a chime.
- AppBar shows a live `Badge` with pending-order count.

### Customer side (`customer/pages/menu_page.dart`)
- New `MyOrders` singleton holding ids placed in this session.
- `MenuPage` is now Stateful; it tracks last-seen status per owned order.
- Status change → snackbar ("Order #1234: Preparing").
- "Your orders" banner at the top of the menu lists session's active orders.

### Audio chime
`lib/shared/chime.dart` exports `playChime()` via conditional import:
- Web → `chime_web.dart` (Web Audio API via `package:web`).
- VM (`flutter test`) → `chime_stub.dart` (no-op).

Two-note sine synthesis with exponential-decay envelope. Browser autoplay
policy caveat: first chime after a cold page load may be silent until any
user gesture has occurred on the tab.

**Dead end:** After adding the chime, user reported "no sound." Verified
the compiled module was present on the dev server (6 KB of DDC output for
`chime_web.dart.lib.js`) but the browser was running cached pre-chime JS.
Fix: hard-refresh (Ctrl+Shift+R). For future reference: Flutter `-d
web-server` doesn't push updates automatically; browser cache must be busted
manually or dev server restarted.

---

## 9. Current state (and what's left)

**Running processes for an end-to-end session:**

```bash
# 1. Backend
cd backend && dart run bin/server.dart

# 2. Customer app
cd .. && flutter run -t lib/customer/main.dart -d web-server \
                     --web-hostname=0.0.0.0 --web-port=8080

# 3. Restaurant app
flutter run -t lib/restaurant/main.dart -d web-server \
             --web-hostname=0.0.0.0 --web-port=8081

# 4. Reverse proxy (systemd)
sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy
```

Open `http://customer.local` and `http://restaurant.local`. Place an order
→ it appears live on the restaurant side with a snackbar and chime. Status
updates on the restaurant side appear live on the customer side.

**Known limitations:**
- Orders live in the backend process's memory — restarting wipes them.
- No auth; "my orders" means "placed from this tab, this session."
- No payments, no delivery tracking, no multi-restaurant.
- SSE reconnect is a flat 2s — add exponential backoff before shipping.
- Chime autoplay restriction — see step 8.
- Android Chrome `.local` resolution isn't guaranteed; iOS Safari is.
- The nvidia-580 package is in a broken state on this system (unrelated to
  this project). Every `apt install` fails at the configure step. We've
  been running single-package installs that succeeded despite the error.

**Natural next steps, from cheap to ambitious:**
1. SQLite persistence in the backend (survive restarts).
2. Order history page on the customer side.
3. Audio: unlock-on-first-click so the first chime isn't ever silent.
4. Web Push notifications (Android works; iOS requires PWA install).
5. Make the apps installable PWAs so iOS gets push.
6. Switch Caddy → nginx (config already written at `dev/nginx.conf`).
7. Real auth (even just email magic links) so "customer" is a real identity.
8. Payment integration.

---

## File inventory

### Flutter (lib/)
```
lib/
├── shared/
│   ├── models/order.dart           # Order, OrderItem, OrderStatus
│   ├── models/menu_item.dart       # MenuItem
│   ├── data/sample_menu.dart       # hardcoded menu
│   ├── api/order_repository.dart   # ChangeNotifier singleton over HTTP+SSE
│   ├── api/order_api_client.dart   # thin HTTP wrapper + SSE parser
│   ├── theme.dart                  # customer orange / restaurant indigo
│   ├── chime.dart                  # conditional export
│   ├── chime_stub.dart             # no-op fallback
│   └── chime_web.dart              # Web Audio chime
├── customer/
│   ├── main.dart                   # CustomerApp entry
│   ├── state/cart.dart             # session cart
│   ├── state/my_orders.dart        # session tracked order ids
│   └── pages/
│       ├── menu_page.dart          # menu + "Your orders" banner + snackbars
│       └── cart_page.dart          # cart + name + place order
├── restaurant/
│   ├── main.dart                   # RestaurantApp entry
│   └── pages/orders_page.dart      # order list + chime + badge
└── dev/
    └── demo.dart                   # split-view (one process, shared repo)
```

### Backend
```
backend/
├── pubspec.yaml
└── bin/server.dart                 # shelf: /orders, /orders/stream (SSE via hijack)
```

### Dev / infra
```
dev/
├── Caddyfile                       # current reverse proxy
├── nginx.conf                      # ready for the migration
├── mdns-publish.sh                 # IP picker + avahi-publish wrapper
└── food-orders-mdns@.service       # systemd template, one unit per alias
```

### Docs
```
CLAUDE.md                           # current-state reference for future sessions
docs/journey.md                     # this file
```
