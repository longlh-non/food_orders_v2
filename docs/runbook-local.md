# Runbook: running food_orders on your own machine

Every task you do by hand, in one place: start, restart, back up, upgrade, configure, check. Commands are copy-paste. Run them from the project folder (`~/flutter_projects/food_orders`) unless a step says otherwise.

- `CLAUDE.md` stays the full reference (API, order rules, menu examples). This page links to it instead of repeating long parts.
- The hosted server (VM) has its own guide: `docs/deploy.md`.

Prerequisite in every new terminal (already in `~/.bashrc`):

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

---

## 1. Start everything

Four processes, each in its own terminal, in this order.

**1. Backend** (port 3000; it stores orders and the menu):

```bash
cd backend
dart pub get                       # first time, or after backend/pubspec.yaml changes
read -r STAFF_ID && read -rs STAFF_PASSWORD && export STAFF_ID STAFF_PASSWORD && dart run bin/server.dart
```

- It waits for two lines: type the staff ID and press Enter, then the staff password and press Enter. The ID is shown as you type; the password isn't (see section 4).
- To start without staff editing, just run `dart run bin/server.dart`.
- It prints where the database and pictures are, whether staff routes are `enabled` or `disabled`, and whether the shop details for reports and bank transfer are `enabled` or `disabled`.
- For bank transfer and the summary report it also needs the shop and bank settings: see section 4a. Without them the app still works with cash only.

**2. Customer app** (port 8080):

```bash
flutter run -t lib/customer/main.dart -d web-server --web-hostname=0.0.0.0 --web-port=8080
```

**3. Restaurant app** (port 8081):

```bash
flutter run -t lib/restaurant/main.dart -d web-server --web-hostname=0.0.0.0 --web-port=8081
```

**4. Reverse proxy.** Caddy runs as a system service, so there's nothing to start each time. Check it's up with `systemctl is-active caddy`. Only after editing `dev/Caddyfile`, reload it (section 2).

Then open http://customer.local and http://restaurant.local.

**Split-screen demo** (optional; the customer app on the left and the restaurant app on the right, sharing one state):

```bash
flutter run -t lib/dev/demo.dart -d chrome --web-port=8082
```

Why this order: the apps load the menu and orders from the backend when they open.
- **Backend not up yet:** the customer menu shows "Không tải được thực đơn" with **Thử lại** (retry). The live order stream reconnects by itself every few seconds.
- **Once the backend is up:** tap Retry or reload the page.

---

## 2. Restart or reload after a change

| I changed… | So I do… |
|---|---|
| Flutter code (`lib/`) | In that app's `flutter run` terminal press **`R`** (hot restart), then hard-refresh the page (**Ctrl+Shift+R**; on iPhone, reload). If the page doesn't change, press **`q`** and start the app again. |
| Backend code (`backend/`) | Stop the backend (**Ctrl+C**) and start it again (section 1). There is no hot reload for the backend. **Always restart after backend code changes:** a backend left running with old code once refused every new order (400). |
| A new schema step in `backend/lib/database.dart` | Back up first (section 3), then restart the backend. The upgrade runs on start. |
| `pubspec.yaml` (either one) | `make bootstrap` (runs `flutter pub get` and `dart pub get` in `backend/`), then restart what changed. |
| `dev/Caddyfile` (for example the 64 KB body limit) | `sudo cp dev/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy` |
| `web/manifest.json` (splash and browser-bar colours) | Nothing shows locally. `flutter run` doesn't serve it ("manifest not generated in run mode"); it only applies to a real build (`flutter build web`). |
| Your wifi network | `sudo systemctl restart 'food-orders-mdns@*'`, so phones find `customer.local` at the new address. |

About `r` and `R` in the `flutter run` terminal: Flutter 3.47 lists **`r` = hot reload**, **`R` = hot restart** and **`q` = quit**, also with `-d web-server`.
- The same terminal warns: "The web-server device requires the Dart Debug Chrome extension for debugging".
- **Unverified:** whether `r`/`R` reach an ordinary browser tab without that extension.
- The safe routine is **`R` plus a hard refresh**; if nothing changes, **`q` and start again**.
- Pulling someone else's changes: do whichever rows above apply (Flutter only, backend only, proxy only, or `make bootstrap`).

---

## 3. Database

**Where it lives:**
- The database is `backend/data/orders.db`. Set `ORDERS_DB=/path/to/file.db` before starting the backend to use another file.
- Menu pictures are in `backend/data/images/`. `IMAGES_DIR=/path` overrides it.
- Both are git-ignored (they hold customer names and your photos); never commit them.

**Schema version:** the database upgrades itself step by step on start. It's at **version 8** now:
- 1: orders;
- 2: menu;
- 3: categories and toppings;
- 4: Ăn vặt;
- 5: pictures;
- 6: sold-out;
- 7: how an order is paid (`payment_method`, `payment_due_at`; old orders read as cash);
- 8: old `pending` and `accepted` orders become `preparing`. **This can't be undone**, so back up first. Restart the backend before you reload the apps, so the upgrade has run.

Check it with `sqlite3 backend/data/orders.db "PRAGMA user_version"`. A failed step rolls back completely and leaves the old version.

**Backup.** Always back up before starting a backend that has a new schema step, and before big hand edits.

```bash
# backend stopped:
cp backend/data/orders.db "backend/data/orders.$(date +%F-%H%M).db"
# or while it runs (needs the sqlite3 CLI):
sqlite3 backend/data/orders.db ".backup backend/data/orders.$(date +%F-%H%M).db"
```

- Back up the pictures with the database: `cp -r backend/data/images "backend/data/images.$(date +%F-%H%M)"`.
- Copies next to the original don't survive a disk failure; copy one elsewhere now and then.

**Restore** (unverified on your real database until you try it once):
1. Stop the backend (Ctrl+C).
2. Keep the current file just in case: `cp backend/data/orders.db backend/data/orders.before-restore.db`
3. Copy the backup you want back: `cp backend/data/orders.2026-11-17-0414.db backend/data/orders.db` (use your file's name).
4. If you also backed up pictures, copy that folder back over `backend/data/images/`.
5. Start the backend. If the backup is from an older schema version, it upgrades again on start.

**Editing the menu and pictures:**
- Use the `sqlite3` CLI (install once: `sudo apt install sqlite3`). The examples (change a price, add an item, Ăn vặt, toppings, pictures, sold out) are in `CLAUDE.md` → "Editing the menu".
- Staff can also change a price or sold-out over HTTP with the staff ID and password (section 4), and **add** an item from the restaurant app (section 3a).
- To add a picture:
  1. copy the file into `backend/data/images/`. Name rules: lowercase letters, digits and `-`, starting with a letter or digit, up to 64 characters before the extension, then `.jpg`, `.jpeg`, `.png` or `.webp`. The file is at most 1 MiB (the full rule is in `CLAUDE.md` → "Editing the menu");
  2. set it with `sqlite3`;
  3. check it at `http://customer.local/api/images/<name>`.

**When the order store is full:**
- The backend keeps at most **10,000 orders**. After that, new orders get "Order storage is full" (503); old orders are never deleted automatically.
- To make room: stop the backend, back up, then delete old finished orders. In this example, **change the date**: it removes delivered and cancelled orders placed before it.

  ```bash
  sqlite3 backend/data/orders.db "DELETE FROM orders WHERE status IN ('delivered', 'cancelled') AND placed_at < '2026-01-01'"
  ```

- The restaurant screen shows only the newest 500 orders.

**Mock orders for testing the Excel reports** (dev only; adds `delivered` and `cancelled` orders with ids starting `mock-`, built from your current menu):
1. Stop the backend and make a dated backup (see **Backup** above).
2. Run it from the project root. It prints the database path and asks you to type `yes`:

   ```bash
   dart run backend/bin/seed_mock_orders.dart                      # last full month, added to what is there
   dart run backend/bin/seed_mock_orders.dart --month=2026-10      # a month you choose
   dart run backend/bin/seed_mock_orders.dart --month=2026-10 --clean   # first delete earlier mock- orders
   ```

   `--db=PATH` picks another file (default: `ORDERS_DB`, else `backend/data/orders.db`); `--yes` skips the question. Running it twice without `--clean` doubles that month's mock data.
3. It refuses to run if the total would reach the 10,000-order limit.
4. Remove all mock orders again (backend stopped):

   ```bash
   sqlite3 backend/data/orders.db "DELETE FROM orders WHERE id LIKE 'mock-%'"
   ```

**Never delete `orders.db` to "re-seed".** That wipes every order and resets the menu to the starting list.

---

## 3a. Add a menu item from the restaurant app

Staff can add a dish or drink without `sqlite3`. It needs the staff ID and password (section 4); without them the backend answers 403 and the app says "Chức năng sửa thực đơn đang tắt trên máy chủ".

1. **If the item has a picture,** first copy the file into `backend/data/images/` (see "To add a picture" in section 3). Name rule: lowercase letters, digits and `-`, then `.webp`, `.jpg`, `.jpeg` or `.png`; for example `xoi-ga.webp`. Skip this for an item without a picture.
2. Open `http://restaurant.local`, press the menu-edit button in the top bar ("Chỉnh sửa thực đơn"), then the add button at the top right ("Thêm món"). The add button appears once the menu has loaded.
3. Type the staff ID and password when asked. The app keeps them only until the page is reloaded.
4. Fill in the form ("Thêm món mới"):
   - **Tên món** (name): required, up to 100 characters;
   - **Mô tả** (description): optional, up to 500 characters;
   - the price in VND, a whole number from 0 to 1,000,000;
   - **Mục** (category): Đồ ăn, Ăn nhẹ, Đồ uống or Ăn vặt. You must choose one;
   - **Cho phép thêm topping**: shown only for Đồ ăn;
   - **Tên tệp ảnh** (picture file name): optional. Type the same name as the file from step 1. The app does **not** check that the file exists: an unknown name just shows the placeholder, so open `http://customer.local/api/images/<name>` to check it.
5. Press "Thêm". A message "Đã thêm: …" appears and the item is available at once. Open `http://customer.local` (reload if it was open) and look under its category.

**The item's id.** The server makes it from the name: lower case, accents removed, `đ` becomes `d`, other characters become `-`, at most 48 characters. "Xôi gà" becomes `xoi-ga`. If that id is taken, it becomes `xoi-ga-2`, then `xoi-ga-3`. The id **never changes** afterwards, even if the name is edited with `sqlite3`; keep it stable (see "Keep ids stable" in `CLAUDE.md` → "Editing the menu").

**If it fails** (except a wrong password, below, the form reopens with what you typed and an error at the top):
- **"Đã có món trùng tên trong mục này":** an item with the same name is already in that category (capitals and accents don't matter). Use another name or category.
- **"Thực đơn đã đầy, không thêm được món nữa":** the menu holds 300 items, the maximum. Remove an item with `sqlite3` first.
- **Wrong staff ID or password (401):** the staff login box opens again with an error (the form is not reopened); retype them. **After 5 wrong tries within 60 seconds** every staff request is refused for 60 seconds (section 4).
- **Editing disabled (403):** the backend was started without a valid `STAFF_ID` and `STAFF_PASSWORD` (section 4).
- **Name, description or picture-name errors:** the message under the field says the limit.

**What the app can't do yet:** rename an item, delete it, or change the description, category or picture of an existing item. These still need `sqlite3`: the commands are in `CLAUDE.md` → "Editing the menu". The app changes only the price and sold-out switch of existing items.

**Before bigger menu edits,** make a dated backup of `orders.db` (and the images folder), as in section 3. A single add is easy to undo with `sqlite3` (`DELETE FROM menu_items WHERE id = '...'`), but a backup is cheap.

**Unverified (owner acceptance):** that these steps work end to end in your browser against the real backend; agents have not clicked through them.

---

## 4. Staff ID and password

Staff-only routes need one shared staff ID and password, set when the backend starts. Today they are the month export (the restaurant app's download button, "Xuất đơn hàng theo tháng", `GET /api/orders/export`), changing a price or sold-out (`PATCH /api/menu/<id>`), adding a menu item (`POST /api/menu`, section 3a), and the two staff payment buttons in the restaurant app ("Đã nhận chuyển khoản" and "Chuyển sang tiền mặt").

**What changed for you:** the old `STAFF_TOKEN` is no longer used. Start the backend with `STAFF_ID` and `STAFF_PASSWORD`, otherwise the export, menu edits and the staff payment buttons stay off (403).

- **Choose them once and keep them safe** (password manager).
  - The ID is 1–64 characters, e.g. `staff`.
  - The password is at least 12 characters. A random one: `openssl rand -hex 12`.
  - Plain letters, digits and symbols only, with no Vietnamese accents: browsers refuse other characters in request headers.
  - Spaces at the start or end are ignored, so don't rely on them.
- **Start with them:**
  ```bash
  cd backend
  read -r STAFF_ID && read -rs STAFF_PASSWORD && export STAFF_ID STAFF_PASSWORD && dart run bin/server.dart
  ```
  Type the ID and press Enter, then the password and press Enter. The ID is shown as you type; the password isn't, and neither value lands in your shell history.
  - Typing `export STAFF_PASSWORD=...` on the command line *would* save it in history, so don't.
  - The values exist only in that terminal; a second terminal doesn't have them.
- **What the answers mean:**
  - **401:** the ID or password is missing or wrong. The server never says which half was wrong.
  - **403:** staff routes are off: the backend was started without valid values.
  - **429:** locked; see the next point.
- **The one-minute lock:**
  - After **5 wrong tries within 60 seconds**, every staff request, even a correct one, is refused for 60 seconds.
  - The lock is for everyone, not per person: behind the proxy every request looks the same.
  - It stops someone on the wifi from guessing the password. The catch is that they can lock staff out for a minute at a time.
- **Changing them:**
  1. Stop the backend (Ctrl+C).
  2. Start it again with new values, using the `read` line above.
  3. Check them (below), then tell staff the new pair.

  There's nowhere else they're stored, so there's nothing to clean up in the database. The old pair stops working at once. An open restaurant tab says "Sai mã nhân viên hoặc mật khẩu" until the new pair is typed.
- **Never** write them into a file inside the project, and never commit them.
- **They cross your wifi in plain text.** `http://restaurant.local` has no HTTPS, so anyone on the same network who captures traffic could read them, and with them download customer names. Use them only on a wifi you trust until HTTPS is set up (for hosting, see the deploy cards).
- **Example edit** (this marks Trà đá sold out):

  ```bash
  curl -X PATCH -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" \
    -H 'Content-Type: application/json' \
    -d '{"available": false}' http://customer.local/api/menu/tra-da
  ```

  This only works in a terminal where you've already set both (the same `read … && export STAFF_ID STAFF_PASSWORD` step). On a shared machine, put the headers in a file and use `curl -H @file`, so other users can't see them with `ps`.

### How to check your staff ID and password

None of these steps prints the password, not even its length.

**1. In the terminal that will start the backend** (before `dart run`):

```bash
[ -n "$STAFF_ID" ] && echo "STAFF_ID is set" || echo "STAFF_ID is NOT set"
[ -n "$STAFF_PASSWORD" ] && echo "STAFF_PASSWORD is set" || echo "STAFF_PASSWORD is NOT set"
[ "${#STAFF_ID}" -ge 1 ] && [ "${#STAFF_ID}" -le 64 ] && echo "ID length OK" || echo "ID must be 1-64 characters"
[ "${#STAFF_PASSWORD}" -ge 12 ] && echo "password long enough" || echo "password too short (needs 12+)"
printf %s "$STAFF_ID" | LC_ALL=C grep -q '[^ -~]' && echo "ID has accents or special characters: not allowed" || echo "ID characters OK"
printf %s "$STAFF_PASSWORD" | LC_ALL=C grep -q '[^ -~]' && echo "password has accents or special characters: not allowed" || echo "password characters OK"
```

(The lengths count spaces at the ends too, but the backend ignores those, so a value of only spaces counts as unset.)

**2. After starting the backend, read its startup line:**

- Good: `staff routes: enabled (STAFF_ID and STAFF_PASSWORD set)`.
- Bad: `staff routes: disabled (STAFF_ID / STAFF_PASSWORD unset or invalid: ID 1-64 characters, password at least 12, printable ASCII)`. Stop the backend and go back to step 1.
- If you also see `note: STAFF_TOKEN is no longer used; set STAFF_ID and STAFF_PASSWORD`:
  1. stop the backend and run `unset STAFF_TOKEN`;
  2. remove it from any shell profile where you set it;
  3. start again.

"Enabled" only means both values are usable, not that staff will type the right ones. Step 3 proves that.

**3. Prove the pair works** with one request from the same terminal (in another terminal, set them again first with the `read … && export STAFF_ID STAFF_PASSWORD` part of the start line, without `dart run`). Put a real month instead of `2026-11`:

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" \
  "http://customer.local/api/orders/export?month=2026-11"
```

`-o /dev/null` throws the downloaded file away and `-w` prints only the status code. `restaurant.local` works too. Without the proxy, use `http://localhost:3000/orders/export?month=2026-11` (no `/api`). While curl runs, other users on the machine can see the headers with `ps`; that's fine on your own laptop.

| Code | Meaning |
|---|---|
| **200** | The pair is right. |
| **401** | Wrong ID or password. |
| **403** | Staff routes are off: see step 2. |
| **429** | Locked after too many wrong tries. Wait up to 60 seconds (`curl -i` shows the exact number in `Retry-After`); a correct pair is refused too until then. |
| **400** | The pair was accepted, but the month isn't `YYYY-MM`. |
| **000** or **502** | Nothing answered: the backend (or the proxy) isn't running. Start it (section 1). |

**Test the right pair once.** Don't test wrong passwords over and over: 5 wrong tries lock every staff member out for a minute.

**4. Does the backend that's already running have them?**
- Look for the `staff routes:` line in that backend's terminal, or run step 3 against it: 200 means yes.
- `ps` doesn't show environment variables. Don't look in `/proc/<pid>/environ`: it prints the password in clear text. Never paste its output anywhere.
- If unsure, stop the backend and start it again from a terminal where steps 1–3 pass.

**5. In the restaurant app:** open the download button ("Xuất đơn hàng theo tháng") and type the ID and password.
- **"Sai mã nhân viên hoặc mật khẩu":** 401, a wrong pair. Both fields are cleared.
- **"Thử sai quá nhiều lần. Thử lại sau N giây."** (or "…Vui lòng thử lại sau."): 429, locked.
- **"Chức năng xuất dữ liệu đang tắt trên máy chủ":** 403, the backend was started without valid values.
- **"Chỉ dùng chữ không dấu, số và ký hiệu thông thường":** the typed value has characters a browser can't send.

The app remembers the pair only until the page is reloaded. The browser's password manager doesn't save it, on purpose: the tablet may be shared.

The variables themselves are listed in section 9.

---

## 4a. Shop and bank settings

Nine settings tell the backend your shop details (for the summary report) and your bank account (for bank transfer). They are read **once, when the backend starts**, so after any change you restart it. Details and rules: `CLAUDE.md` → "Shop and bank settings".

| Variable | What it is | Rule |
|---|---|---|
| `SHOP_NAME` | first line of the summary report, written exactly as you type it | up to 200 characters |
| `SHOP_TAX_CODE` | tax code | digits and `-`, up to 20 characters |
| `SHOP_ADDRESS` | address | up to 200 characters |
| `SHOP_LOCATION` | business location | up to 200 characters |
| `SHOP_REPRESENTATIVE` | name under the signature line | up to 100 characters |
| `BANK_BIN` | your bank's 6-digit id | exactly 6 digits |
| `BANK_ACCOUNT` | account number | digits only, up to 19 |
| `BANK_ACCOUNT_NAME` | account holder name shown to the customer | up to 100 characters |
| `BANK_NAME` | bank name shown to the customer | up to 100 characters |

- **What switches on:** all five `SHOP_*` = the summary report; all four `BANK_*` = bank transfer. If one value is missing or wrong, only that feature stays off and the backend still starts.
- **Where to put them:** nowhere in the project. Type them at the start command (below) so they stay out of your shell history and out of every file. **Never commit them.** (On a hosted server they go in the service's environment file instead: see `docs/deploy.md`.)
- **Start with them** (stop the backend first if it runs, Ctrl+C):

  ```bash
  cd backend
  read -r STAFF_ID && read -rs STAFF_PASSWORD && export STAFF_ID STAFF_PASSWORD
  for v in SHOP_NAME SHOP_TAX_CODE SHOP_ADDRESS SHOP_LOCATION SHOP_REPRESENTATIVE \
           BANK_BIN BANK_ACCOUNT BANK_ACCOUNT_NAME BANK_NAME; do
    read -r -p "$v: " "$v" && export "$v"
  done
  dart run bin/server.dart
  ```

  It asks for the staff ID and password first, then each setting by name; type the value and press Enter. Accents are fine in the shop and bank texts. A value with only spaces or empty counts as not set.
- **Check:** read the two startup lines. Good: `shop details for reports: enabled` and `bank transfer: enabled`. Otherwise `disabled (missing or invalid: ...)` lists the variable **names** to fix; values are never printed. Stop the backend, start it again and re-type.
- **Try it:** with `bank transfer: enabled`, place a bank-transfer order in the customer app. The page should show a QR, the bank name, account number, account name, the amount and a transfer content like `DH` + 6 digits. In the restaurant app the same order shows "Chưa thanh toán" and the buttons "Đã nhận chuyển khoản" and "Chuyển sang tiền mặt".
- **Unverified (owner acceptance):** scanning the QR with a real banking app and seeing the right account and amount. Agents can't scan. Try a small amount yourself.
- **How payment works for staff:**
  - Look in your bank app for the transfer content shown on the card; when the money is there, tap "Đã nhận chuyển khoản".
  - After 5 minutes without payment the order is cancelled by the server. The customer can switch to cash or get a new QR within 15 minutes of that; you can switch an expired order to cash at any time ("Chuyển sang tiền mặt").
  - A transfer that arrives late (or twice) is sorted out by hand in your bank app; the app never moves money and can't confirm a cancelled order.

---

## 4b. Download the monthly reports

In the restaurant app, press the download button in the top bar ("Xuất đơn hàng theo tháng"), choose the month and the report, type the staff ID and password, then "Tải xuống".

| Choice | File | Needs |
|---|---|---|
| "Báo cáo tổng hợp theo ngày (Excel)" (preselected) | `bao-cao-tong-hop-YYYY-MM.xlsx` (sheets `gộp` and `tách`) | the five `SHOP_*` settings (section 4a); otherwise "Chưa cài đặt thông tin quán trên máy chủ" |
| "Chi tiết từng đơn trong tháng (Excel)" | `chi-tiet-YYYY-MM.xlsx` | nothing extra |
| "Danh sách dòng món (CSV)" | `orders-YYYY-MM.csv` | nothing extra |

- Both Excel reports count only **`delivered`** orders, and put each order on the day written in its `placedAt` (the customer's phone clock). They show no customer names. The summary lists every day of the month (0 on days without orders); the detail report skips days without orders.
- The CSV lists every order line with all statuses and customer names. Keep it private.
- **From a terminal** instead (put a real month; the staff ID and password must be set in that terminal, see section 4):

  ```bash
  curl -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" -o bao-cao-tong-hop-2026-11.xlsx "http://customer.local/api/orders/export?month=2026-11&report=summary"
  curl -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" -o chi-tiet-2026-11.xlsx "http://customer.local/api/orders/export?month=2026-11&report=detail"
  curl -H "X-Staff-Id: $STAFF_ID" -H "X-Staff-Password: $STAFF_PASSWORD" -o orders-2026-11.csv "http://customer.local/api/orders/export?month=2026-11"
  ```

- **No data to try it on?** Add fake orders with the mock tool (section 3), then delete them again.
- Old USD test orders (prices like `9.5`) don't add up in Vietnamese Excel; delete them first (after a backup).
- **Unverified (owner acceptance):** that Excel shows the reports like your sample files. Agents can't open Excel.

---

## 4c. Languages

Both apps speak 10 languages: Tiếng Việt (the default), English, Deutsch, Español, Français, Русский, ລາວ, 日本語, 中文, 한국어. Background and rules: "Languages" in `CLAUDE.md`.

### Change the language of an app

1. Open the app (customer menu or restaurant orders screen) and tap the **globe icon** in the top bar.
2. Pick a language. The whole app switches at once; the current one has a check mark.
3. The choice is remembered **in that browser, for that site**. The customer site and the restaurant site remember separately, and a different browser or phone starts again in Vietnamese. It survives a reload.

To forget the choice (back to Vietnamese): in Chrome open DevTools (F12), then Application, Local storage, pick the site, delete the key `food_orders_locale`, and reload. Clearing the site's data in the browser settings does the same.

Not translated, on purpose: the monthly CSV and Excel reports, server error messages, and menu item names and descriptions (they stay as stored in the database). Prices always show as `25.000 VNĐ`. The browser tab title follows the language; the installed-app name (`web/manifest.json`) stays "Đặt Món".

### Add an 11th language

Example: Thai, code `th`. Every step is needed; the tests catch a missing one.

1. Copy `lib/shared/l10n/app_vi.arb` to `lib/shared/l10n/app_th.arb`. Set `"@@locale": "th"` and translate **every** key (a key missing in one language fails the test). Keep placeholders such as `{name}` unchanged. Plural messages need the forms of that language.
2. In `lib/shared/locale_controller.dart`, add `Locale('th')` to `LocaleController.supported`. The list order is the picker order.
3. In `lib/shared/widgets/language_picker.dart`, add the language's own name to the `_nativeNames` map (e.g. `'th': 'ไทย'`). Without it the picker shows the bare code.
4. Update the tests that pin the list: `test/shared/arb_completeness_test.dart` and `test/shared/locale_controller_test.dart` (count 10 to 11, new code in the set), the names map in `test/shared/language_picker_test.dart`, and the `hasLength(10)` check on `AppLocalizations.supportedLocales` in `test/restaurant_l10n_test.dart`. Any other test that fails after step 2 pins the list too; `make test` shows which.
5. Check that Flutter's own widgets have the language (`flutter_localizations` covers most, Lao was checked for Material text only, in `test/shared/app_localizations_smoke_test.dart`); a language it doesn't cover needs extra work, so ask first.
6. Run `flutter pub get` (or `flutter gen-l10n`) to regenerate `lib/shared/l10n/app_localizations*.dart`, then `make test`, then `make check`. Commit the new generated files with the ARB file.
7. Add the language to the review log below, marked "not reviewed", and update the wording note in `lib/shared/l10n/README.md`.

### Review or update one language's wording

1. Give the language's file (`lib/shared/l10n/app_xx.arb`) to a fluent speaker. Each line is `"key": "text"`; they correct only the text, never the key or `{placeholders}`.
2. Apply the corrections in the ARB file, run `flutter gen-l10n`, `make test`, and check the screens in the app (long words can overflow buttons).
3. Record the sign-off in the table below: date, who reviewed, what was covered. Then update the wording note in `CLAUDE.md` ("Languages") and `lib/shared/l10n/README.md`.

### Language review log

State as of 2026-11-23. "Not reviewed" means the text is a machine-translated draft that no fluent speaker has checked; it ships that way with the owner's explicit acceptance.

| Language | Code | Status | Date | Reviewer |
|---|---|---|---|---|
| Tiếng Việt | `vi` | owner-accepted (the text accepted earlier; strings added since, in the menu editor, export dialog and payment buttons, are drafts awaiting acceptance) | 2026-11-23 | owner |
| English | `en` | not reviewed (partly restored from the old English, partly redrafted) | | |
| 中文 | `zh` | not reviewed (machine-translated) | | |
| ລາວ | `lo` | not reviewed (machine-translated) | | |
| Español | `es` | not reviewed (machine-translated) | | |
| Français | `fr` | not reviewed (machine-translated) | | |
| Русский | `ru` | not reviewed (machine-translated; plural forms need care) | | |
| Deutsch | `de` | not reviewed (machine-translated) | | |
| 한국어 | `ko` | not reviewed (machine-translated) | | |
| 日本語 | `ja` | not reviewed (machine-translated) | | |

---

## 5. Proxy, local names and phones

**Caddy:**
- It runs as a system service on port 80. It sends `customer.local` → `localhost:8080`, `restaurant.local` → `localhost:8081`, and `/api/*` → `localhost:3000` (with `/api` removed).
- Don't also run `caddy run` by hand; port 80 can only have one listener.
- Status: `systemctl is-active caddy`. Logs: `sudo journalctl -u caddy -f`.

**nginx instead** (foreground, stop Caddy first):

```bash
sudo systemctl stop caddy
sudo nginx -c $PWD/dev/nginx.conf -p $PWD
# stop it:
sudo nginx -c $PWD/dev/nginx.conf -p $PWD -s stop
```

**Request size:** both proxies refuse request bodies over **64 KB** on `/api/*`. The limit lives in the proxy config, so changing it means editing `dev/Caddyfile` (or `dev/nginx.conf`) and reloading.

**Backend address:**
- It listens on **`127.0.0.1:3000` only** (this machine), so other devices can't go around the proxy.
- `BIND_ADDRESS=0.0.0.0` changes that; only use it behind a firewall.
- Check with `ss -ltn | grep 3000`.

**Local names on the laptop** (one time): `sudo tee -a /etc/hosts <<< "127.0.0.1  customer.local  restaurant.local"`

**Phones on the same wifi (iOS):**
- One-time setup is in `CLAUDE.md` → "Mobile access".
- Port 80 must be open: `sudo ufw allow 80/tcp`.
- Check from the laptop: `avahi-resolve -n customer.local` should print your LAN address.
- After changing wifi, restart the mDNS services (section 2).

---

## 6. Checks

Run these from the project folder. `make check` runs them all, in the same order as CI.

| Command | What it does |
|---|---|
| `make check` | Everything below. Run it before committing. |
| `make format-check` | Reports Dart files that aren't formatted (changes nothing). |
| `make format` | The only target that rewrites files: formats all Dart code. |
| `make analyze` | Flutter analyzer, strict. |
| `make test` | Flutter app tests. |
| `make backend-analyze` | Backend analyzer, strict. |
| `make backend-test` | Backend tests. The first run downloads a prebuilt SQLite, so it needs network. |
| `make boundaries` | Checks that the customer and restaurant apps don't import each other. |
| `make bootstrap` | `flutter pub get` plus `dart pub get` in `backend/`. |
| `make hooks-install` / `make hooks-uninstall` | Turn on or off the optional git hook that checks formatting before each commit. |

---

## 7. CI today

- GitHub Actions runs `make check` on pushes to `main` and on every pull request (`.github/workflows/ci.yml`). A push to a PR branch is now designed to trigger exactly one run (via `pull_request`), not two: before `ci-dependabot-and-triggers` landed, `on: push` (all branches) plus `on: pull_request` ran the same gate twice for every PR branch push.
- **Dependabot** (`.github/dependabot.yml`) checks weekly for updates to GitHub Actions (`/`) and the Dart packages in `/` (the Flutter app) and `/backend`, each capped at 3 open pull requests. Every Dependabot PR runs the same `make check` gate as any other PR. It does **not** bump the Flutter version in `ci.yml` (`flutter-version`) — see the comment next to that line; the owner updates it by hand together with their local Flutter. A `sqlite3` bump (in `backend/pubspec.yaml`) changes the precompiled binary its build hook downloads, so that PR always needs a human look before merging — never auto-merge it.
- **Build job (`ci-build-artifacts`):** after `check` passes, a second job `build` runs `bash deploy/build.sh` (both web apps), compile-checks the backend with `dart build cli` (not `dart compile exe`, which refuses the `sqlite3` build hook; the bundle is **not** uploaded), checks the web builds for `.env*` files and the words `STAFF_ID` / `STAFF_PASSWORD`, then uploads `customer-web` and `restaurant-web` as separate artifacts kept 7 days. Only `contents: read`, no secrets. **Unverified until pushed:** this job has never run on GitHub, so the artifacts and their `index.html` are not confirmed yet.
- The GitHub remote is `origin` → `https://github.com/longlh-non/food_orders.git` (from `git remote -v`).
- **At the time of writing (2026-11-19):** two commits are pushed, the latest being `de44cc3` "App demo 1st version". `git status -sb` showed `main...origin/main`, so nothing is waiting to be pushed.
- Work done after that commit is still uncommitted on this laptop, and CI checks it only once you commit and push it.
- `git status` shows what's uncommitted. Agents never commit or push unless you ask.
- **Unverified until the owner pushes:** that a PR branch push now starts exactly one run, and that Dependabot opens its weekly pull requests.

---

## 8. Deploy (CD) status

**Deploy guide:** the step-by-step server guide is `docs/deploy.md` (written, **not yet followed on a real VM, so unverified**). It covers the VM, firewall, Caddy and the shared password, the backend service, DNS, releases and backups. Going to the public internet is covered there; this runbook is for your own machine.

**Automatic CD is not built yet.** CI builds both web apps and compile-checks the backend (section 7, unverified until pushed and run on GitHub), but nothing is deployed from it; releases are by hand as in `docs/deploy.md`. Note the backend is built with `dart build cli` (not `dart compile exe`), on the VM, so its CPU architecture matches. HOST1 (provider) and HOST2 (domain) are still open owner decisions. The decisions so far are in `docs/ci-cd-decisions.md`. The cards in `docs/tasks/`:

| Card | What it adds |
|---|---|
| `ci-dependabot-and-triggers` | CI runs once per change; weekly dependency-update pull requests. |
| `ci-build-artifacts` | CI builds both web apps and compile-checks the backend after the checks pass (web builds uploaded; backend binary not, D5). |
| `deploy-production-config` | Production Caddy config, services, backups for the server. |
| `deploy-demo-access-gate` | A shared password on the public demo. |
| `deploy-runbook` | `docs/deploy.md`, the server guide (links here); landed, unverified on a real server. |
| `cd-server-deploy-script` | A deploy script on the server: back up, switch release, health check, roll back. |
| `cd-github-deploy-workflow` | Deploy from GitHub when you push a version tag, after your approval. |

Status (2026-11-23): the first five cards are done (in `docs/tasks/done/`); only `cd-server-deploy-script` and `cd-github-deploy-workflow` are still open. The open ones update sections 7 and 8 here when they land.

---

## 9. Configuration reference

**Environment variables** (backend; an empty value counts as unset):

| Variable | Default | Effect |
|---|---|---|
| `ORDERS_DB` | `backend/data/orders.db` | The database file to use. |
| `IMAGES_DIR` | `backend/data/images` | The menu pictures folder (created on start). |
| `STAFF_ID` | unset (staff routes off) | The shared staff ID: 1–64 printable ASCII characters (section 4). |
| `STAFF_PASSWORD` | unset (staff routes off) | The shared staff password: at least 12 printable ASCII characters (section 4). Both must be set for staff routes to work. |
| `STAFF_TOKEN` | — | No longer used; ignored. If it's set, the backend prints a note at start. |
| `SHOP_NAME`, `SHOP_TAX_CODE`, `SHOP_ADDRESS`, `SHOP_LOCATION`, `SHOP_REPRESENTATIVE` | unset (summary report off) | The shop details on the summary report; all five needed (section 4a). |
| `BANK_BIN`, `BANK_ACCOUNT`, `BANK_ACCOUNT_NAME`, `BANK_NAME` | unset (bank transfer off) | The bank account for bank transfer; all four needed (section 4a). |
| `BIND_ADDRESS` | `127.0.0.1` | Where the backend listens. Keep the default unless you're behind a firewall. |

**Files and folders:**

| Path | What |
|---|---|
| `backend/data/orders.db` | Orders and the menu (git-ignored). |
| `backend/data/orders.YYYY-MM-DD-HHMM.db` | Your dated backups. |
| `backend/data/images/` | Menu pictures (git-ignored). |
| `dev/Caddyfile` → `/etc/caddy/Caddyfile` | Proxy config: edit the first, copy it to the second, reload. |
| `dev/nginx.conf` | The nginx alternative. |
| `dev/mdns-publish.sh`, `dev/food-orders-mdns@.service` | The phone names (mDNS). |
| `docs/ci-cd-decisions.md` | Your CI/CD decisions. |

**Ports and addresses:**

| Port | What | Open it at |
|---|---|---|
| 80 | Caddy (or nginx) | http://customer.local, http://restaurant.local |
| 3000 | Backend (this machine only) | via the proxy: `/api/...` |
| 8080 | Customer app (dev server) | via the proxy |
| 8081 | Restaurant app (dev server) | via the proxy |
| 8082 | Split-screen demo | http://localhost:8082 |

---

## 10. Known gaps (not verified by an agent)

- **Hot reload:** whether `r`/`R` work on `-d web-server` without the Dart Debug Chrome extension (section 2).
- **Restore:** restoring a backup on your real database (section 3).
- **Proxy, mDNS and services:** the Caddy and nginx reloads, mDNS and the systemd services. Agents can't run `sudo`.
- **Phones:** anything on the iPhone.
- **Order store:** the "storage full" clean-up on real data.
- **Bank transfer QR:** scanning it with a real banking app (right account and amount), and the 5-minute expiry and renew flow on real phones (section 4a).
- **Excel reports:** how Excel shows them compared with your sample files (section 4b).
- **Languages:** the wording of 9 of the 10 languages (section 4c), that the globe picker works on real phones, and that Lao, Chinese, Japanese, Korean and Russian text draws without missing characters in a browser.
- **Generated language files on CI:** `app_localizations*.dart` were generated with Flutter 3.50.1 locally; CI pins 3.47.7. Whether the checks give the same result there is unverified until CI runs.
