import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Opens the backend's SQLite database at [path] and brings its schema up to
/// date. Pass `':memory:'` for a throwaway database (tests).
///
/// For a file path, the parent directory is created if it doesn't exist.
/// Also sets a 2 second busy timeout and runs [migrate]. The caller owns the
/// returned handle and closes it (`bin/server.dart` on exit, tests at the end);
/// `OrdersApi` and `MenuApi` only borrow it.
Database openDatabase(String path) {
  if (path != ':memory:') {
    File(path).parent.createSync(recursive: true);
  }
  final db = path == ':memory:' ? sqlite3.openInMemory() : sqlite3.open(path);
  // If the owner is editing the file with the sqlite3 CLI at the same moment,
  // wait up to 2 s for their write to finish instead of failing the request.
  db.execute('PRAGMA busy_timeout = 2000');
  migrate(db);
  return db;
}

/// Creates or upgrades the tables, using SQLite's built-in `user_version`
/// number to remember which steps already ran. Each step runs once, inside a
/// transaction, so a crash halfway leaves the database at the previous
/// version instead of half-upgraded.
///
/// To change the schema later, add the next `if (db.userVersion < N)` step below —
/// never edit a step that has already shipped.
///
/// Steps so far: 1 `orders` table; 2 `menu_items` with placeholder items;
/// 3 categories, toppings and the real menu; 4 the `nibble` category;
/// 5 `image` column; 6 `available` column; 7 payment columns on `orders`;
/// 8 `pending`/`accepted` orders become `preparing`;
/// 9 `delivered` orders become `finished`, `ready` orders become `preparing`.
void migrate(Database db) {
  // Step 1: the `orders` table (id, customer name, status, placement time, and
  // the items as one JSON string).
  if (db.userVersion < 1) {
    db.execute('BEGIN');
    try {
      // Items are stored as one JSON string: they are always read and written
      // together with their order and never queried on their own.
      db.execute('''
        CREATE TABLE orders (
          id            TEXT PRIMARY KEY,
          customer_name TEXT NOT NULL,
          status        TEXT NOT NULL,
          placed_at     TEXT NOT NULL,
          items_json    TEXT NOT NULL
        )
      ''');
      db.userVersion = 1;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 2: the `menu_items` table (id, name, description, price in VND) with
  // CHECKs that keep hand edits sane, filled once with 5 placeholder items
  // ([seedMenuV2]) that step 3 removes again.
  if (db.userVersion < 2) {
    db.execute('BEGIN');
    try {
      db.execute('''
        CREATE TABLE menu_items (
          id          TEXT PRIMARY KEY,
          name        TEXT NOT NULL CHECK (typeof(name) = 'text'),
          description TEXT NOT NULL DEFAULT ''
                      CHECK (typeof(description) = 'text'),
          -- The menu is edited by hand with the sqlite3 CLI, and SQLite would
          -- otherwise store `'abc'` as text or `9e999` as Infinity, which
          -- breaks GET /menu. The upper bound only blocks Infinity; it is not
          -- a business price limit.
          price       REAL NOT NULL
                      CHECK (typeof(price) IN ('real', 'integer')
                             AND price >= 0 AND price <= 1000000000)
        )
      ''');
      // Filled once, in this step. Because the step never runs again, items
      // the owner later edits or deletes stay that way across restarts.
      final insert = db.prepare(
        'INSERT INTO menu_items (id, name, description, price) '
        'VALUES (?, ?, ?, ?)',
      );
      try {
        for (final item in seedMenuV2) {
          insert.execute([
            item['id'],
            item['name'],
            item['description'],
            item['price'],
          ]);
        }
      } finally {
        insert.close();
      }
      db.userVersion = 2;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 3: categories (food / snack / drink), a per-dish "takes toppings"
  // switch, the toppings list, and the owner's real menu (VND) replacing
  // step 2's placeholders.
  if (db.userVersion < 3) {
    db.execute('BEGIN');
    try {
      db.execute(
        "ALTER TABLE menu_items ADD COLUMN category TEXT NOT NULL "
        "DEFAULT 'food' CHECK (category IN ('food', 'snack', 'drink'))",
      );
      db.execute(
        'ALTER TABLE menu_items ADD COLUMN allow_toppings INTEGER NOT NULL '
        'DEFAULT 1 CHECK (allow_toppings IN (0, 1))',
      );
      db.execute('''
        CREATE TABLE toppings (
          id    TEXT PRIMARY KEY,
          name  TEXT NOT NULL CHECK (typeof(name) = 'text'),
          price REAL NOT NULL
                CHECK (typeof(price) IN ('real', 'integer')
                       AND price >= 0 AND price <= 1000000000)
        )
      ''');
      // The step-2 placeholders. Past orders keep their own copies of names
      // and prices, so removing menu rows never changes an order.
      db.execute(
        'DELETE FROM menu_items WHERE id IN '
        '(${List.filled(removedInStep3.length, '?').join(', ')})',
        removedInStep3,
      );
      // OR IGNORE: if the owner already created an item with one of these
      // ids by hand, keep theirs instead of failing the whole upgrade.
      final insertItem = db.prepare(
        'INSERT OR IGNORE INTO menu_items '
        '(id, name, description, price, category, allow_toppings) '
        'VALUES (?, ?, ?, ?, ?, ?)',
      );
      final insertTopping = db.prepare(
        'INSERT OR IGNORE INTO toppings (id, name, price) VALUES (?, ?, ?)',
      );
      try {
        for (final item in seedMenu) {
          insertItem.execute([
            item['id'],
            item['name'],
            item['description'],
            item['price'],
            item['category'],
            item['allowToppings'] == true ? 1 : 0,
          ]);
        }
        for (final topping in seedToppings) {
          insertTopping.execute([
            topping['id'],
            topping['name'],
            topping['price'],
          ]);
        }
      } finally {
        insertItem.close();
        insertTopping.close();
      }
      db.userVersion = 3;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 4: a 4th category, `nibble` = "Ăn vặt" (owner, 2026-11-11). It
  // starts empty: no item is moved or added. SQLite can't change a CHECK on
  // an existing column, so the table is rebuilt the documented way (new
  // table, copy, drop, rename), keeping every column, every CHECK and the
  // row order (GET /menu sorts by rowid).
  if (db.userVersion < 4) {
    db.execute('BEGIN');
    try {
      db.execute('''
        CREATE TABLE menu_items_new (
          id             TEXT PRIMARY KEY,
          name           TEXT NOT NULL CHECK (typeof(name) = 'text'),
          description    TEXT NOT NULL DEFAULT ''
                         CHECK (typeof(description) = 'text'),
          price          REAL NOT NULL
                         CHECK (typeof(price) IN ('real', 'integer')
                                AND price >= 0 AND price <= 1000000000),
          category       TEXT NOT NULL DEFAULT 'food'
                         CHECK (category IN ('food', 'snack', 'drink', 'nibble')),
          allow_toppings INTEGER NOT NULL DEFAULT 1
                         CHECK (allow_toppings IN (0, 1))
        )
      ''');
      db.execute(
        'INSERT INTO menu_items_new '
        '(id, name, description, price, category, allow_toppings) '
        'SELECT id, name, description, price, category, allow_toppings '
        'FROM menu_items ORDER BY rowid',
      );
      db.execute('DROP TABLE menu_items');
      db.execute('ALTER TABLE menu_items_new RENAME TO menu_items');
      db.userVersion = 4;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 5: an optional picture per menu item, stored as a file name in the
  // images folder (e.g. `xoi-thit.webp`), never a URL or the bytes. NULL
  // means "no picture". The CHECK is a coarse guard against hand edits
  // (characters and length, so no `/`, `..`, `%` or spaces); the exact rule
  // is `menuImageName` in `menu_image.dart`. Existing rows get NULL.
  if (db.userVersion < 5) {
    db.execute('BEGIN');
    try {
      db.execute('''
        ALTER TABLE menu_items ADD COLUMN image TEXT
          CHECK (image IS NULL
                 OR (typeof(image) = 'text'
                     AND length(image) BETWEEN 5 AND 80
                     AND image NOT GLOB '*[^a-z0-9.-]*'))
      ''');
      db.userVersion = 5;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 6: a "sold out" switch per menu item. 1 = can be ordered, 0 = sold
  // out. Existing rows stay available. It is changed with the staff-only
  // `PATCH /menu/{id}` or the sqlite3 CLI.
  if (db.userVersion < 6) {
    db.execute('BEGIN');
    try {
      db.execute(
        'ALTER TABLE menu_items ADD COLUMN available INTEGER NOT NULL '
        'DEFAULT 1 CHECK (available IN (0, 1))',
      );
      db.userVersion = 6;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 7: how an order is paid. NULL in both columns = an order from
  // before this step; the API reads it back as cash. `payment_due_at` is an
  // ISO-8601 UTC string set by the server for bank transfer orders.
  if (db.userVersion < 7) {
    db.execute('BEGIN');
    try {
      db.execute(
        'ALTER TABLE orders ADD COLUMN payment_method TEXT '
        "CHECK (payment_method IS NULL OR payment_method IN ('cash', 'bank_transfer'))",
      );
      db.execute('ALTER TABLE orders ADD COLUMN payment_due_at TEXT');
      db.userVersion = 7;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 8: the statuses `pending` and `accepted` are gone; stored orders in
  // them become `preparing` (owner, PAY11 and PAY12). Can't be undone: make a
  // dated backup first.
  if (db.userVersion < 8) {
    db.execute('BEGIN');
    try {
      db.execute(
        "UPDATE orders SET status = 'preparing' "
        "WHERE status IN ('pending', 'accepted')",
      );
      db.userVersion = 8;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  // Step 9: the statuses `delivered` and `ready` are gone (SF3): a stored
  // `delivered` order becomes `finished`, a stored `ready` order becomes
  // `preparing`. `orders.status` has no CHECK, so the table is not rebuilt.
  // Can't be undone: make a dated backup first.
  if (db.userVersion < 9) {
    db.execute('BEGIN');
    try {
      db.execute(
        "UPDATE orders SET status = 'finished' WHERE status = 'delivered'",
      );
      db.execute(
        "UPDATE orders SET status = 'preparing' WHERE status = 'ready'",
      );
      db.userVersion = 9;
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

/// The placeholder menu that schema step 2 wrote. Kept unchanged because
/// step 2 has already run on real databases ("never edit a shipped step");
/// step 3 removes these items again and inserts the owner's real menu.
const seedMenuV2 = <Map<String, Object>>[
  {
    'id': 'burger',
    'name': 'Classic Burger',
    'description': 'Beef patty, lettuce, tomato, house sauce',
    'price': 9.50,
  },
  {
    'id': 'pizza',
    'name': 'Margherita Pizza',
    'description': 'Tomato, mozzarella, fresh basil',
    'price': 12.00,
  },
  {
    'id': 'salad',
    'name': 'Caesar Salad',
    'description': 'Romaine, parmesan, croutons, caesar dressing',
    'price': 7.50,
  },
  {
    'id': 'fries',
    'name': 'Fries',
    'description': 'Hand-cut, sea salt',
    'price': 3.50,
  },
  {'id': 'soda', 'name': 'Soda', 'description': '330ml can', 'price': 2.00},
];

/// The ids step 3 removes: step 2's placeholder menu (burger, pizza, salad,
/// fries) and soda, which the owner dropped.
const removedInStep3 = ['burger', 'pizza', 'salad', 'fries', 'soda'];

/// The owner's real menu (2026-11-11), written by step 3. Prices are VND,
/// names exactly as the owner gave them. Each entry has the same shape
/// `GET /menu` returns. Editing this list doesn't change an existing
/// database: use the sqlite3 CLI for that (see CLAUDE.md).
///
/// The `an-nhe-*` snacks are the toppings sold on their own. They're
/// separate rows from [seedToppings], so a price change has to be made in
/// both places.
const seedMenu = <Map<String, Object>>[
  // Đồ ăn: foods, which take toppings.
  {
    'id': 'xoi-thit',
    'name': 'Xôi thịt',
    'description': '',
    'price': 25000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'xoi-cha',
    'name': 'Xôi chả',
    'description': '',
    'price': 25000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'xoi-ruoc',
    'name': 'Xôi ruốc',
    'description': '',
    'price': 25000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'xoi-trung-op',
    'name': 'Xôi trứng ốp',
    'description': '',
    'price': 23000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'xoi-trung-ran',
    'name': 'Xôi trứng rán',
    'description': '',
    'price': 23000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'xoi-xuc-xich',
    'name': 'Xôi xúc xích',
    'description': '',
    'price': 25000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'mi-tom-trung-chan',
    'name': 'Mì tôm trứng chần',
    'description': '',
    'price': 23000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'mi-tom-trung-op',
    'name': 'Mì tôm trứng ốp',
    'description': '',
    'price': 25000.0,
    'category': 'food',
    'allowToppings': true,
  },
  {
    'id': 'mi-tom-bo',
    'name': 'Mì tôm bò',
    'description': '',
    'price': 30000.0,
    'category': 'food',
    'allowToppings': true,
  },
  // Ăn nhẹ: snacks, no toppings.
  {
    'id': 'trung-ngai-cuu',
    'name': 'Trứng ngải cứu',
    'description': '',
    'price': 10000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  {
    'id': 'lap-xuong-nuong-da',
    'name': 'Lạp xưởng nướng đá',
    'description': '',
    'price': 15000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  {
    'id': 'an-nhe-cha',
    'name': 'Chả',
    'description': '',
    'price': 10000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  {
    'id': 'an-nhe-thit',
    'name': 'Thịt',
    'description': '',
    'price': 10000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  {
    'id': 'an-nhe-trung-trang',
    'name': 'Trứng tráng',
    'description': '',
    'price': 8000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  {
    'id': 'an-nhe-xuc-xich',
    'name': 'Xúc xích',
    'description': '',
    'price': 10000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  {
    'id': 'an-nhe-lap-xuong',
    'name': 'Lạp xưởng',
    'description': '',
    'price': 12000.0,
    'category': 'snack',
    'allowToppings': false,
  },
  // Đồ uống: drinks, no toppings.
  {
    'id': 'tra-da',
    'name': 'Trà đá',
    'description': '',
    'price': 4000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'nuoc-dong-chai',
    'name': 'Nước đóng chai',
    'description': '',
    'price': 12000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'lavie',
    'name': 'Lavie',
    'description': '',
    'price': 6000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'lavie-them-khoang',
    'name': 'Lavie thêm khoáng',
    'description': '',
    'price': 10000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'bo-huc',
    'name': 'Bò húc',
    'description': '',
    'price': 20000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'tra-chanh',
    'name': 'Trà chanh',
    'description': '',
    'price': 15000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'tra-quat',
    'name': 'Trà quất',
    'description': '',
    'price': 15000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'ca-phe-den',
    'name': 'Đen',
    'description': '',
    'price': 20000.0,
    'category': 'drink',
    'allowToppings': false,
  },
  {
    'id': 'ca-phe-nau',
    'name': 'Nâu (Cà phê sữa)',
    'description': '',
    'price': 25000.0,
    'category': 'drink',
    'allowToppings': false,
  },
];

/// The toppings any food with `allow_toppings = 1` can take, written by
/// step 3. Prices are VND. Like [seedMenu], this only fills a brand-new
/// database.
const seedToppings = <Map<String, Object>>[
  {'id': 'cha', 'name': 'Thêm chả', 'price': 10000.0},
  {'id': 'thit', 'name': 'Thêm thịt', 'price': 10000.0},
  {'id': 'trung-trang', 'name': 'Thêm trứng tráng', 'price': 8000.0},
  {'id': 'xuc-xich', 'name': 'Thêm xúc xích', 'price': 10000.0},
  {'id': 'lap-xuong', 'name': 'Thêm lạp xưởng', 'price': 12000.0},
];
