import 'dart:convert';
import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/menu_api.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

Future<Response> call(Handler handler, String method, String path) {
  return Future.sync(
    () => handler(Request(method, Uri.parse('http://localhost$path'))),
  );
}

/// The seeded menu as `GET /menu` returns it: every item also has `image`,
/// null until a picture is set (schema step 5), and `available`, true until
/// it is marked sold out (step 6).
final seedMenuJson = [
  for (final item in seedMenu) {...item, 'image': null, 'available': true},
];

Future<List<Object?>> getMenu(Handler handler) async {
  final response = await call(handler, 'GET', '/menu');
  return jsonDecode(await response.readAsString()) as List<Object?>;
}

void main() {
  late Database db;
  late Handler handler;

  setUp(() {
    db = openDatabase(':memory:');
    handler = MenuApi(db).handler;
  });

  tearDown(() => db.close());

  group('GET /menu', () {
    test('returns the seeded menu as JSON, in insertion order', () async {
      final response = await call(handler, 'GET', '/menu');

      expect(response.statusCode, 200);
      // Menu text is Vietnamese, so shelf declares UTF-8 explicitly.
      expect(response.headers['content-type'], startsWith('application/json'));
      expect(
        jsonDecode(await response.readAsString()),
        seedMenuJson,
      ); // same items, same order, same prices
    });

    test('every item has the documented field types', () async {
      final menu = await getMenu(handler);

      expect(menu, hasLength(seedMenu.length));
      for (final item in menu.cast<Map<String, dynamic>>()) {
        expect(
          item.keys,
          unorderedEquals([
            'id',
            'name',
            'description',
            'price',
            'category',
            'allowToppings',
            'image',
            'available',
          ]),
        );
        expect(item['available'], isA<bool>());
        expect(item['category'], isIn(['food', 'snack', 'drink', 'nibble']));
        expect(item['image'], anyOf(isNull, isA<String>()));
        expect(item['allowToppings'], isA<bool>());
        expect(item['id'], isA<String>().having((s) => s, 'id', isNotEmpty));
        expect(item['name'], isA<String>());
        expect(item['description'], isA<String>());
        expect(item['price'], isA<num>());
      }
      final ids = menu.map((i) => (i as Map)['id']).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('reflects a change made directly in SQL (no caching)', () async {
      await getMenu(handler);
      db.execute("UPDATE menu_items SET price = 26000 WHERE id = 'xoi-thit'");

      final menu = await getMenu(handler);

      final burger = menu.cast<Map<String, dynamic>>().firstWhere(
        (i) => i['id'] == 'xoi-thit',
      );
      expect(burger['price'], 26000);
    });

    // POST /menu is a staff route now (menu_add_test.dart); with no staff gate
    // on this handler it answers 403, which this loop doesn't pin down.
    for (final method in ['PATCH', 'PUT', 'DELETE']) {
      test('$method /menu is not allowed', () async {
        final response = await call(handler, method, '/menu');

        expect(response.statusCode, isNot(200));
        expect(await getMenu(handler), seedMenuJson);
      });
    }
  });

  // Mirrors bin/server.dart: both APIs behind one Cascade on one port.
  group('combined with OrdersApi like the server', () {
    late OrdersApi orders;
    late Handler combined;

    setUp(() {
      orders = OrdersApi(db);
      combined = Cascade().add(handler).add(orders.handler).handler;
    });

    tearDown(() => orders.close());

    test('serves /menu, /toppings and /orders', () async {
      expect((await call(combined, 'GET', '/menu')).statusCode, 200);
      expect((await call(combined, 'GET', '/toppings')).statusCode, 200);
      expect((await call(combined, 'GET', '/orders')).statusCode, 200);
    });

    test('a staff PATCH for an unknown id is 404 through the cascade, and '
        'a missing token is 401 (it stops the cascade)', () async {
      const token = 'staff-token-for-tests-1234';
      final staffCombined = Cascade()
          .add(
            MenuApi(
              db,
              staffGate: StaffGate(id: testStaffId, password: token),
            ).handler,
          )
          .add(orders.handler)
          .handler;
      Future<Response> patch(String id, {String? sent}) => Future.sync(
        () => staffCombined(
          Request(
            'PATCH',
            Uri.parse('http://localhost/menu/$id'),
            headers: staffCreds(sent),
            body: '{"price": 1000}',
          ),
        ),
      );

      final unknown = await patch('nope', sent: token);
      final noToken = await patch('tra-da');

      expect(unknown.statusCode, 404);
      expect(noToken.statusCode, 401);
      expect(
        db
            .select("SELECT price FROM menu_items WHERE id = 'tra-da'")
            .single['price'],
        4000,
      );
    });

    test('placing an order works through the combined handler', () async {
      final response = await Future.sync(
        () => combined(
          Request(
            'POST',
            Uri.parse('http://localhost/orders'),
            body: jsonEncode({
              'id': '1',
              'customerName': 'Bao',
              'items': [
                {'name': 'Fries', 'quantity': 1, 'price': 3.5},
              ],
              'status': 'preparing',
              'placedAt': '2026-11-09T12:00:00.000',
            }),
          ),
        ),
      );

      expect(response.statusCode, 200);
    });

    test('an unknown order still answers "Order not found"', () async {
      final response = await Future.sync(
        () => combined(
          Request(
            'PATCH',
            Uri.parse('http://localhost/orders/nope'),
            body: jsonEncode({'status': 'ready'}),
          ),
        ),
      );

      expect(response.statusCode, 404);
      expect(await response.readAsString(), 'Order not found');
    });

    test('write methods on /menu are still refused', () async {
      for (final method in ['POST', 'PATCH', 'DELETE']) {
        final response = await call(combined, method, '/menu');
        expect(response.statusCode, isNot(200), reason: method);
      }
    });
  });

  group('schema steps 2 and 3 (menu_items, toppings)', () {
    // Now 6: later steps run too (4 nibble, 5 pictures, 6 sold out).
    test('a fresh database ends at user_version 8 with the real menu', () {
      expect(db.userVersion, 8);
      expect(
        db.select('SELECT id FROM menu_items'),
        hasLength(seedMenu.length),
      );
      expect(
        db.select('SELECT id FROM toppings'),
        hasLength(seedToppings.length),
      );
    });

    test('running the migration again does not add items', () {
      migrate(db);
      migrate(db);

      expect(
        db.select('SELECT id FROM menu_items'),
        hasLength(seedMenu.length),
      );
      expect(
        db.select('SELECT id FROM toppings'),
        hasLength(seedToppings.length),
      );
    });

    test(
      'a version-1 database with orders gets the menu and keeps the orders',
      () {
        // Build the state a database had before this card: orders table only,
        // user_version 1. Same DDL as step 1 in database.dart.
        final v1 = sqlite3.openInMemory();
        addTearDown(v1.close);
        v1.execute('''
        CREATE TABLE orders (
          id            TEXT PRIMARY KEY,
          customer_name TEXT NOT NULL,
          status        TEXT NOT NULL,
          placed_at     TEXT NOT NULL,
          items_json    TEXT NOT NULL
        )
      ''');
        v1.execute(
          "INSERT INTO orders VALUES ('1', 'Alice', 'pending', "
          "'2026-10-30T12:00:00.000', '[]')",
        );
        v1.userVersion = 1;

        migrate(v1);

        expect(v1.userVersion, 8);
        expect(
          v1.select('SELECT id FROM menu_items'),
          hasLength(seedMenu.length),
        );
        expect(v1.select('SELECT id FROM orders').single['id'], '1');
      },
    );

    for (final (label, sql) in [
      (
        'a negative price',
        "UPDATE menu_items SET price = -1 WHERE id = 'tra-da'",
      ),
      (
        'a text price',
        "UPDATE menu_items SET price = 'abc' WHERE id = 'tra-da'",
      ),
      (
        'an infinite price',
        "UPDATE menu_items SET price = 9e999 WHERE id = 'tra-da'",
      ),
      (
        // A number like 5 is stored as the text '5' (harmless); a binary blob
        // is not converted, so that's what the CHECK has to catch.
        'a binary name',
        "UPDATE menu_items SET name = X'00ff' WHERE id = 'tra-da'",
      ),
      (
        'a NULL description',
        "UPDATE menu_items SET description = NULL WHERE id = 'tra-da'",
      ),
    ]) {
      test('the table refuses $label', () {
        expect(() => db.execute(sql), throwsA(isA<SqliteException>()));
      });
    }

    test(
      'a database opened from a file waits instead of failing when busy',
      () {
        expect(db.select('PRAGMA busy_timeout').single.values.single, 2000);
      },
    );
  });

  group('schema step 3 (categories, toppings, real menu)', () {
    /// A database exactly as step 2 left it: the placeholder menu, plus an
    /// item the owner added by hand and one order.
    Database versionTwoDatabase({String extraId = 'tea'}) {
      final v2 = sqlite3.openInMemory();
      v2.execute('''
        CREATE TABLE orders (
          id TEXT PRIMARY KEY, customer_name TEXT NOT NULL,
          status TEXT NOT NULL, placed_at TEXT NOT NULL,
          items_json TEXT NOT NULL
        )
      ''');
      v2.execute('''
        CREATE TABLE menu_items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL CHECK (typeof(name) = 'text'),
          description TEXT NOT NULL DEFAULT ''
                      CHECK (typeof(description) = 'text'),
          price REAL NOT NULL CHECK (typeof(price) IN ('real', 'integer')
                                     AND price >= 0 AND price <= 1000000000)
        )
      ''');
      for (final item in seedMenuV2) {
        v2.execute('INSERT INTO menu_items VALUES (?, ?, ?, ?)', [
          item['id'],
          item['name'],
          item['description'],
          item['price'],
        ]);
      }
      v2.execute("INSERT INTO menu_items VALUES (?, 'Owner item', '', 5000)", [
        extraId,
      ]);
      v2.execute(
        "INSERT INTO orders VALUES ('1', 'Alice', 'pending', "
        "'2026-10-30T12:00:00.000', '[]')",
      );
      v2.userVersion = 2;
      return v2;
    }

    test('removes the placeholders and adds the real menu', () {
      final v2 = versionTwoDatabase();
      addTearDown(v2.close);

      migrate(v2);

      final ids = v2.select('SELECT id FROM menu_items').map((r) => r['id']);
      expect(v2.userVersion, 8);
      for (final old in removedInStep3) {
        expect(ids, isNot(contains(old)), reason: old);
      }
      for (final item in seedMenu) {
        expect(ids, contains(item['id']));
      }
    });

    test("keeps the owner's own items and every order", () async {
      final v2 = versionTwoDatabase();
      addTearDown(v2.close);

      migrate(v2);

      final menu = (await getMenu(MenuApi(v2).handler))
          .cast<Map<String, dynamic>>();
      final tea = menu.firstWhere((i) => i['id'] == 'tea');
      expect(tea['category'], 'food');
      expect(tea['allowToppings'], isTrue);
      expect(v2.select('SELECT id FROM orders').single['id'], '1');
    });

    test('an owner item that already uses a new id is kept, not an error', () {
      final v2 = versionTwoDatabase(extraId: 'tra-da');
      addTearDown(v2.close);

      migrate(v2);

      final row = v2.select("SELECT name FROM menu_items WHERE id = 'tra-da'");
      expect(row.single['name'], 'Owner item');
      expect(v2.userVersion, 8);
    });

    test('a failed step 3 rolls back completely and leaves version 2', () {
      final v2 = versionTwoDatabase();
      addTearDown(v2.close);
      // Make step 3 fail halfway: its CREATE TABLE toppings now errors,
      // after the two ALTER TABLEs have already run inside the transaction.
      v2.execute('CREATE TABLE toppings (x INTEGER)');

      expect(() => migrate(v2), throwsA(isA<SqliteException>()));

      expect(v2.userVersion, 2);
      final columns = v2
          .select('PRAGMA table_info(menu_items)')
          .map((r) => r['name']);
      expect(columns, isNot(contains('category')));
      expect(columns, isNot(contains('allow_toppings')));
      final ids = v2.select('SELECT id FROM menu_items').map((r) => r['id']);
      expect(ids, containsAll(removedInStep3)); // nothing was deleted
      expect(v2.select('SELECT id FROM orders'), hasLength(1));
    });

    test('Vietnamese names come back from GET /menu unchanged', () async {
      final response = await call(handler, 'GET', '/menu');
      final menu = (jsonDecode(await response.readAsString()) as List)
          .cast<Map<String, dynamic>>();

      expect(
        menu.map((i) => i['name']),
        containsAll([
          'Mì tôm trứng chần',
          'Nâu (Cà phê sữa)',
          'Lạp xưởng nướng đá',
        ]),
      );
    });

    test('foods, snacks and drinks have the right category and toppings '
        'flag', () async {
      final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();

      for (final item in menu) {
        final expected = seedMenu.firstWhere((s) => s['id'] == item['id']);
        expect(item['category'], expected['category'], reason: item['id']);
        expect(
          item['allowToppings'],
          item['category'] == 'food',
          reason: '${item['id']}: only foods take toppings',
        );
      }
      expect(menu.where((i) => i['category'] == 'food'), hasLength(9));
      expect(menu.where((i) => i['category'] == 'snack'), hasLength(7));
      expect(menu.where((i) => i['category'] == 'drink'), hasLength(9));
    });

    test(
      'a drink never reports allowToppings, whatever the column says',
      () async {
        db.execute(
          "UPDATE menu_items SET allow_toppings = 1 WHERE id = 'tra-da'",
        );

        final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();

        expect(
          menu.firstWhere((i) => i['id'] == 'tra-da')['allowToppings'],
          isFalse,
        );
      },
    );

    test('a food switched to "no toppings" reports false', () async {
      db.execute(
        "UPDATE menu_items SET allow_toppings = 0 WHERE id = 'xoi-thit'",
      );

      final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();

      expect(
        menu.firstWhere((i) => i['id'] == 'xoi-thit')['allowToppings'],
        isFalse,
      );
    });

    for (final (label, sql) in [
      (
        'an unknown category',
        "UPDATE menu_items SET category = 'beverage' WHERE id = 'tra-da'",
      ),
      (
        'an allow_toppings of 2',
        "UPDATE menu_items SET allow_toppings = 2 WHERE id = 'xoi-thit'",
      ),
      (
        'a negative topping price',
        "UPDATE toppings SET price = -1 WHERE id = 'cha'",
      ),
      (
        'a text topping price',
        "UPDATE toppings SET price = 'free' WHERE id = 'cha'",
      ),
      (
        'a binary topping name',
        "UPDATE toppings SET name = X'00ff' WHERE id = 'cha'",
      ),
    ]) {
      test('the tables refuse $label', () {
        expect(() => db.execute(sql), throwsA(isA<SqliteException>()));
      });
    }
  });

  group('schema step 4 (nibble = Ăn vặt, table rebuild)', () {
    /// A database exactly as step 3 left it, with the owner's typical hand
    /// edits: a changed price, an added item, a deleted item, a topping edit
    /// and an order.
    Database versionThreeDatabase() {
      final v3 = sqlite3.openInMemory();
      v3.execute('''
        CREATE TABLE orders (
          id TEXT PRIMARY KEY, customer_name TEXT NOT NULL,
          status TEXT NOT NULL, placed_at TEXT NOT NULL,
          items_json TEXT NOT NULL
        )
      ''');
      v3.execute('''
        CREATE TABLE menu_items (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL CHECK (typeof(name) = 'text'),
          description TEXT NOT NULL DEFAULT ''
                      CHECK (typeof(description) = 'text'),
          price REAL NOT NULL CHECK (typeof(price) IN ('real', 'integer')
                                     AND price >= 0 AND price <= 1000000000),
          category TEXT NOT NULL DEFAULT 'food'
                   CHECK (category IN ('food', 'snack', 'drink')),
          allow_toppings INTEGER NOT NULL DEFAULT 1
                         CHECK (allow_toppings IN (0, 1))
        )
      ''');
      v3.execute('''
        CREATE TABLE toppings (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL CHECK (typeof(name) = 'text'),
          price REAL NOT NULL CHECK (typeof(price) IN ('real', 'integer')
                                     AND price >= 0 AND price <= 1000000000)
        )
      ''');
      for (final item in seedMenu) {
        v3.execute('INSERT INTO menu_items VALUES (?, ?, ?, ?, ?, ?)', [
          item['id'],
          item['name'],
          item['description'],
          item['price'],
          item['category'],
          item['allowToppings'] == true ? 1 : 0,
        ]);
      }
      for (final t in seedToppings) {
        v3.execute('INSERT INTO toppings VALUES (?, ?, ?)', [
          t['id'],
          t['name'],
          t['price'],
        ]);
      }
      v3.execute("UPDATE menu_items SET price = 27000 WHERE id = 'xoi-thit'");
      v3.execute(
        "INSERT INTO menu_items VALUES ('xoi-ga', 'Xôi gà', 'mới', 30000, "
        "'food', 0)",
      );
      v3.execute("DELETE FROM menu_items WHERE id = 'lavie'");
      v3.execute("UPDATE toppings SET price = 11000 WHERE id = 'cha'");
      v3.execute(
        "INSERT INTO orders VALUES ('1', 'Bao', 'preparing', "
        "'2026-11-11T09:00:00.000', '[]')",
      );
      v3.userVersion = 3;
      return v3;
    }

    List<Map<String, Object?>> allRows(Database d, String table) => [
      for (final row in d.select(
        // Orders: only the columns that existed before step 7.
        table == 'orders'
            ? 'SELECT id, customer_name, status, placed_at, items_json '
                  'FROM orders ORDER BY rowid'
            : 'SELECT * FROM $table ORDER BY rowid',
      ))
        Map.of(row),
    ];

    test('a fresh database (now version 8) has no Ăn vặt items', () {
      expect(db.userVersion, 8);
      expect(
        db.select('SELECT id FROM menu_items'),
        hasLength(seedMenu.length),
      );
      expect(
        db.select("SELECT id FROM menu_items WHERE category = 'nibble'"),
        isEmpty,
      );
    });

    test('keeps every row, column and the order; toppings and orders too', () {
      final v3 = versionThreeDatabase();
      addTearDown(v3.close);
      final menuBefore = allRows(v3, 'menu_items');
      final toppingsBefore = allRows(v3, 'toppings');
      final ordersBefore = allRows(v3, 'orders');

      migrate(v3);

      // Steps 5 and 6 run too and add `image` (NULL) and `available` (1);
      // every other column is kept.
      expect(v3.userVersion, 8);
      expect([
        for (final row in allRows(v3, 'menu_items'))
          Map.of(row)
            ..remove('image')
            ..remove('available'),
      ], menuBefore);
      expect(
        allRows(v3, 'menu_items').map((r) => r['image']),
        everyElement(isNull),
      );
      expect(allRows(v3, 'toppings'), toppingsBefore);
      expect(allRows(v3, 'orders'), ordersBefore);
      expect(
        v3.select("SELECT id FROM menu_items WHERE category = 'nibble'"),
        isEmpty,
      );
    });

    test('GET /menu lists the same items in the same order after the '
        'upgrade', () async {
      final v3 = versionThreeDatabase();
      addTearDown(v3.close);
      // Read straight from the table: today's GET /menu also selects
      // `image`, which a version 3 file doesn't have yet.
      final before = [
        for (final row in v3.select(
          'SELECT id, name, price, category FROM menu_items ORDER BY rowid',
        ))
          [row['id'], row['name'], row['price'], row['category']],
      ];

      migrate(v3);

      final after = (await getMenu(MenuApi(v3).handler))
          .cast<Map<String, dynamic>>();
      expect([
        for (final i in after) [i['id'], i['name'], i['price'], i['category']],
      ], before);
    });

    test('running the migration again changes nothing', () {
      final v3 = versionThreeDatabase();
      addTearDown(v3.close);
      migrate(v3);
      final after = allRows(v3, 'menu_items');

      migrate(v3);

      expect(v3.userVersion, 8);
      expect(allRows(v3, 'menu_items'), after);
    });

    test('leaves no helper table, trigger or view behind', () {
      final objects = db
          .select(
            "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
          )
          .map((r) => '${r['type']}:${r['name']}')
          .toSet();

      expect(objects, {'table:orders', 'table:menu_items', 'table:toppings'});
    });

    test(
      'the documented Ăn vặt example works and is never "toppings"',
      () async {
        db.execute(
          'INSERT INTO menu_items '
          '(id, name, description, price, category, allow_toppings) '
          "VALUES ('khoai-lang-nuong', 'Khoai lang nướng', '', 15000, "
          "'nibble', 0)",
        );
        db.execute(
          "UPDATE menu_items SET allow_toppings = 1 WHERE id = 'khoai-lang-nuong'",
        );

        final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();
        final khoai = menu.firstWhere((i) => i['id'] == 'khoai-lang-nuong');

        expect(khoai['category'], 'nibble');
        expect(khoai['allowToppings'], isFalse);
      },
    );

    test('an existing item can be moved to Ăn vặt', () {
      db.execute(
        "UPDATE menu_items SET category = 'nibble', allow_toppings = 0 "
        "WHERE id = 'trung-ngai-cuu'",
      );

      final row = db.select(
        "SELECT category FROM menu_items WHERE id = 'trung-ngai-cuu'",
      );
      expect(row.single['category'], 'nibble');
    });

    for (final (label, sql) in [
      (
        'category "cake"',
        "UPDATE menu_items SET category = 'cake' WHERE id = 'tra-da'",
      ),
      (
        'an empty category',
        "UPDATE menu_items SET category = '' WHERE id = 'tra-da'",
      ),
      (
        'a NULL category',
        "UPDATE menu_items SET category = NULL WHERE id = 'tra-da'",
      ),
      (
        'a negative price',
        "UPDATE menu_items SET price = -1 WHERE id = 'tra-da'",
      ),
      (
        'a price over 1e9',
        "UPDATE menu_items SET price = 2e9 WHERE id = 'tra-da'",
      ),
      (
        'a binary name',
        "UPDATE menu_items SET name = X'00ff' WHERE id = 'tra-da'",
      ),
      (
        'allow_toppings = 2',
        "UPDATE menu_items SET allow_toppings = 2 WHERE id = 'xoi-thit'",
      ),
      (
        'a duplicate id',
        "INSERT INTO menu_items (id, name, price) VALUES ('tra-da', 'x', 1)",
      ),
    ]) {
      test('after the rebuild the table still refuses $label', () {
        expect(() => db.execute(sql), throwsA(isA<SqliteException>()));
      });
    }

    test('a failed step 4 rolls back completely and leaves version 3', () {
      final v3 = versionThreeDatabase();
      addTearDown(v3.close);
      final menuBefore = allRows(v3, 'menu_items');
      // Make step 4 fail: its CREATE TABLE menu_items_new now errors.
      v3.execute('CREATE TABLE menu_items_new (x INTEGER)');

      expect(() => migrate(v3), throwsA(isA<SqliteException>()));

      expect(v3.userVersion, 3);
      expect(allRows(v3, 'menu_items'), menuBefore);
      expect(
        () => v3.execute(
          "UPDATE menu_items SET category = 'nibble' WHERE id = 'tra-da'",
        ),
        throwsA(isA<SqliteException>()),
        reason: 'the old CHECK (without nibble) is still in place',
      );
    });
  });

  group('schema step 5 (menu pictures)', () {
    /// A version 4 file: today's database with the `image` column removed,
    /// plus owner edits (a price, an Ăn vặt item) and an order.
    Database versionFourDatabase() {
      final v4 = openDatabase(':memory:');
      v4.execute('ALTER TABLE orders DROP COLUMN payment_method');
      v4.execute('ALTER TABLE orders DROP COLUMN payment_due_at');
      v4.execute('ALTER TABLE menu_items DROP COLUMN available');
      v4.execute('ALTER TABLE menu_items DROP COLUMN image');
      v4.userVersion = 4;
      v4.execute("UPDATE menu_items SET price = 27000 WHERE id = 'xoi-thit'");
      v4.execute(
        'INSERT INTO menu_items '
        '(id, name, description, price, category, allow_toppings) '
        "VALUES ('khoai-lang-nuong', 'Khoai lang nướng', '', 15000, "
        "'nibble', 0)",
      );
      v4.execute(
        "INSERT INTO orders VALUES ('1', 'Bao', 'preparing', "
        "'2026-11-13T09:00:00.000', '[]')",
      );
      return v4;
    }

    List<Map<String, Object?>> allRows(Database d, String table) => [
      for (final row in d.select(
        // Orders: only the columns that existed before step 7.
        table == 'orders'
            ? 'SELECT id, customer_name, status, placed_at, items_json '
                  'FROM orders ORDER BY rowid'
            : 'SELECT * FROM $table ORDER BY rowid',
      ))
        Map.of(row),
    ];

    test('every GET /menu item has image: null on a fresh database', () async {
      final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();

      expect(menu, hasLength(seedMenu.length));
      expect(
        menu.map((i) => i['id']),
        seedMenu.map((i) => i['id']),
        reason: 'order unchanged',
      );
      for (final item in menu) {
        expect(item.containsKey('image'), isTrue, reason: '${item['id']}');
        expect(item['image'], isNull);
      }
    });

    test('a set name is returned; setting NULL removes it', () async {
      db.execute(
        "UPDATE menu_items SET image = 'xoi-thit.webp' WHERE id = 'xoi-thit'",
      );
      Future<Object?> imageOf(String id) async =>
          (await getMenu(handler))
              .cast<Map<String, dynamic>>()
              .firstWhere((i) => i['id'] == id)['image'];

      expect(await imageOf('xoi-thit'), 'xoi-thit.webp');

      db.execute("UPDATE menu_items SET image = NULL WHERE id = 'xoi-thit'");
      expect(await imageOf('xoi-thit'), isNull);
    });

    for (final bad in <Object>[
      '../x.png',
      'a/b.png',
      'a b.png',
      '%2e%2e.png',
      'Burger.webp',
      '',
      42,
      '${'a' * 196}.png',
    ]) {
      test('the table refuses ${bad is String ? '"$bad"' : bad}', () {
        expect(
          () => db.execute(
            "UPDATE menu_items SET image = ? WHERE id = 'xoi-thit'",
            [bad],
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(
          db
              .select("SELECT image FROM menu_items WHERE id = 'xoi-thit'")
              .single['image'],
          isNull,
        );
      });
    }

    for (final sneaky in ['burger.gif', '.hidden.png', 'a..b.png', '-x.png']) {
      test('"$sneaky" passes the table but GET /menu returns null', () async {
        db.execute("UPDATE menu_items SET image = ? WHERE id = 'xoi-thit'", [
          sneaky,
        ]);
        final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();
        expect(menu.firstWhere((i) => i['id'] == 'xoi-thit')['image'], isNull);
      });
    }

    test('a version 4 file migrates (now to 8) and keeps everything', () {
      final v4 = versionFourDatabase();
      addTearDown(v4.close);
      final menuBefore = allRows(v4, 'menu_items');
      final toppingsBefore = allRows(v4, 'toppings');
      final ordersBefore = allRows(v4, 'orders');

      migrate(v4);

      expect(v4.userVersion, 8);
      expect([
        for (final row in allRows(v4, 'menu_items'))
          Map.of(row)
            ..remove('image')
            ..remove('available'),
      ], menuBefore);
      expect(
        allRows(v4, 'menu_items').map((r) => r['image']),
        everyElement(isNull),
      );
      expect(allRows(v4, 'toppings'), toppingsBefore);
      expect(allRows(v4, 'orders'), ordersBefore);
    });

    test('migrating twice changes nothing', () {
      final v4 = versionFourDatabase();
      addTearDown(v4.close);
      migrate(v4);
      v4.execute(
        "UPDATE menu_items SET image = 'xoi-thit.webp' WHERE id = 'xoi-thit'",
      );
      final after = allRows(v4, 'menu_items');

      migrate(v4);

      expect(v4.userVersion, 8);
      expect(allRows(v4, 'menu_items'), after);
    });
  });

  group('schema step 6 (sold out)', () {
    /// A version 5 file: today's database without `available`, plus owner
    /// edits (a price, an Ăn vặt item, a picture) and an order.
    Database versionFiveDatabase() {
      final v5 = openDatabase(':memory:');
      v5.execute('ALTER TABLE orders DROP COLUMN payment_method');
      v5.execute('ALTER TABLE orders DROP COLUMN payment_due_at');
      v5.execute('ALTER TABLE menu_items DROP COLUMN available');
      v5.userVersion = 5;
      v5.execute("UPDATE menu_items SET price = 27000 WHERE id = 'xoi-thit'");
      v5.execute(
        "UPDATE menu_items SET image = 'xoi-thit.webp' WHERE id = 'xoi-thit'",
      );
      v5.execute(
        'INSERT INTO menu_items '
        '(id, name, description, price, category, allow_toppings) '
        "VALUES ('khoai-lang-nuong', 'Khoai lang nướng', '', 15000, "
        "'nibble', 0)",
      );
      v5.execute(
        "INSERT INTO orders VALUES ('1', 'Bao', 'preparing', "
        "'2026-11-13T09:00:00.000', '[]')",
      );
      return v5;
    }

    List<Map<String, Object?>> allRows(Database d, String table) => [
      for (final row in d.select(
        // Orders: only the columns that existed before step 7.
        table == 'orders'
            ? 'SELECT id, customer_name, status, placed_at, items_json '
                  'FROM orders ORDER BY rowid'
            : 'SELECT * FROM $table ORDER BY rowid',
      ))
        Map.of(row),
    ];

    test('every GET /menu item is available on a fresh database', () async {
      final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();

      expect(menu, hasLength(seedMenu.length));
      for (final item in menu) {
        expect(item['available'], isTrue, reason: '${item['id']}');
        expect(item.containsKey('category'), isTrue);
        expect(item.containsKey('image'), isTrue);
      }
    });

    test('a row set to 0 in SQL shows false on the next GET', () async {
      db.execute("UPDATE menu_items SET available = 0 WHERE id = 'tra-da'");

      final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();

      expect(menu.firstWhere((i) => i['id'] == 'tra-da')['available'], isFalse);
      expect(
        menu.where((i) => i['id'] != 'tra-da').map((i) => i['available']),
        everyElement(isTrue),
      );
    });

    for (final bad in <Object?>[2, -1, 'yes', null]) {
      test('the table refuses available = ${bad ?? 'NULL'}', () {
        expect(
          () => db.execute(
            "UPDATE menu_items SET available = ? WHERE id = 'tra-da'",
            [bad],
          ),
          throwsA(isA<SqliteException>()),
        );
      });
    }

    test('a version 5 file migrates to 8 and keeps everything', () {
      final v5 = versionFiveDatabase();
      addTearDown(v5.close);
      final menuBefore = allRows(v5, 'menu_items');
      final toppingsBefore = allRows(v5, 'toppings');
      final ordersBefore = allRows(v5, 'orders');

      migrate(v5);

      expect(v5.userVersion, 8);
      expect([
        for (final row in allRows(v5, 'menu_items'))
          Map.of(row)..remove('available'),
      ], menuBefore);
      expect(
        allRows(v5, 'menu_items').map((r) => r['available']),
        everyElement(1),
      );
      expect(
        v5
            .select("SELECT image FROM menu_items WHERE id = 'xoi-thit'")
            .single['image'],
        'xoi-thit.webp',
      );
      expect(
        v5
            .select(
              "SELECT category FROM menu_items WHERE id = 'khoai-lang-nuong'",
            )
            .single['category'],
        'nibble',
      );
      expect(allRows(v5, 'toppings'), toppingsBefore);
      expect(allRows(v5, 'orders'), ordersBefore);
    });

    test('migrating twice changes nothing', () {
      final v5 = versionFiveDatabase();
      addTearDown(v5.close);
      migrate(v5);
      v5.execute("UPDATE menu_items SET available = 0 WHERE id = 'tra-da'");
      final after = allRows(v5, 'menu_items');

      migrate(v5);

      expect(v5.userVersion, 8);
      expect(allRows(v5, 'menu_items'), after);
    });
  });

  group('PATCH /menu/{id} (staff only)', () {
    const token = 'staff-token-for-tests-1234';
    late Handler staff;

    setUp(
      () => staff = MenuApi(
        db,
        staffGate: StaffGate(id: testStaffId, password: token),
      ).handler,
    );

    Future<Response> patch(
      Handler h,
      String id, {
      Object? body,
      String? rawBody,
      String? sentToken = token,
    }) => Future.sync(
      () => h(
        Request(
          'PATCH',
          Uri.parse('http://localhost/menu/$id'),
          headers: staffCreds(sentToken),
          body: rawBody ?? (body == null ? null : jsonEncode(body)),
        ),
      ),
    );

    Map<String, Object?> row(String id) =>
        Map.of(db.select('SELECT * FROM menu_items WHERE id = ?', [id]).single);

    test('no header -> 401, row unchanged', () async {
      final before = row('xoi-thit');
      final response = await patch(
        staff,
        'xoi-thit',
        body: {'price': 1},
        sentToken: null,
      );
      expect(response.statusCode, 401);
      expect(row('xoi-thit'), before);
    });

    test('wrong token (same and other length) -> 401', () async {
      final before = row('xoi-thit');
      final sameLength = 'X${token.substring(1)}';
      for (final wrong in [sameLength, 'short', '${token}x']) {
        final response = await patch(
          staff,
          'xoi-thit',
          body: {'price': 1},
          sentToken: wrong,
        );
        expect(response.statusCode, 401, reason: wrong);
      }
      expect(row('xoi-thit'), before);
    });

    for (final (label, gate) in [
      ('no token configured (default MenuApi)', null),
      (
        'a token shorter than 16',
        StaffGate(id: testStaffId, password: 'too-short'),
      ),
    ]) {
      test('$label -> 403 even with a header, row unchanged', () async {
        final before = row('xoi-thit');
        final h = MenuApi(db, staffGate: gate).handler;
        final response = await patch(h, 'xoi-thit', body: {'price': 1});
        expect(response.statusCode, 403);
        expect(row('xoi-thit'), before);
      });
    }

    test(
      'a price change is saved and returned in the GET /menu shape',
      () async {
        final before = row('tra-da');

        final response = await patch(staff, 'xoi-thit', body: {'price': 27000});

        expect(response.statusCode, 200);
        final item =
            jsonDecode(await response.readAsString()) as Map<String, dynamic>;
        expect(item['price'], 27000);
        expect(item.keys.toSet(), (seedMenuJson.first as Map).keys.toSet());
        final menu = (await getMenu(handler)).cast<Map<String, dynamic>>();
        final xoi = menu.firstWhere((i) => i['id'] == 'xoi-thit');
        expect(xoi, item);
        expect(xoi['available'], isTrue, reason: 'other fields unchanged');
        expect(row('tra-da'), before, reason: 'other items unchanged');
      },
    );

    test('available false, then true again', () async {
      var response = await patch(staff, 'tra-da', body: {'available': false});
      expect(response.statusCode, 200);
      expect(row('tra-da')['available'], 0);
      final price = row('tra-da')['price'];

      response = await patch(staff, 'tra-da', body: {'available': true});
      expect(response.statusCode, 200);
      expect(row('tra-da')['available'], 1);
      expect(row('tra-da')['price'], price);
    });

    test('both fields together', () async {
      final response = await patch(
        staff,
        'tra-da',
        body: {'price': 5000, 'available': false},
      );
      expect(response.statusCode, 200);
      expect(row('tra-da')['price'], 5000);
      expect(row('tra-da')['available'], 0);
    });

    test('a whole price sent as 27000.0 is accepted', () async {
      final response = await patch(
        staff,
        'tra-da',
        rawBody: '{"price": 27000.0}',
      );
      expect(response.statusCode, 200);
      expect(row('tra-da')['price'], 27000);
    });

    test('the highest allowed price is accepted', () async {
      final response = await patch(
        staff,
        'tra-da',
        body: {'price': maxMenuPrice},
      );
      expect(response.statusCode, 200);
    });

    for (final (label, raw) in <(String, String)>[
      ('{}', '{}'),
      ('[]', '[]'),
      ('not JSON', '{price: 1'),
      ('an empty body', ''),
      ('an extra key', '{"price": 1, "name": "x"}'),
      ('only an unknown key', '{"name": "x"}'),
      ('a negative price', '{"price": -1}'),
      ('a string price', '{"price": "1000"}'),
      ('a null price', '{"price": null}'),
      ('price 1e999', '{"price": 1e999}'),
      ('price ${maxMenuPrice + 1}', '{"price": ${maxMenuPrice + 1}}'),
      ('a bool price', '{"price": true}'),
      ('a fractional price', '{"price": 25000.5}'),
      ('available as a string', '{"available": "false"}'),
      ('available as a number', '{"available": 0}'),
      ('available null', '{"available": null}'),
    ]) {
      test('$label -> 400, row unchanged', () async {
        final before = row('tra-da');
        final response = await patch(staff, 'tra-da', rawBody: raw);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), isNot(contains('name')));
        expect(row('tra-da'), before);
      });
    }

    test('an unknown id -> 404', () async {
      final response = await patch(staff, 'nope', body: {'price': 1});
      expect(response.statusCode, 404);
    });

    test('an id with SQL in it -> 404, the table is intact', () async {
      final evil = Uri.encodeComponent("'; DROP TABLE menu_items;--");
      final response = await patch(staff, evil, body: {'price': 1});
      expect(response.statusCode, 404);
      expect(
        db.select('SELECT COUNT(*) AS n FROM menu_items').first['n'],
        seedMenu.length,
      );
    });

    test('a body over $maxMenuEditBytes bytes -> 413, row unchanged', () async {
      final before = row('tra-da');
      final big = '{"price": 1, "pad": "${'a' * maxMenuEditBytes}"}';
      final response = await patch(staff, 'tra-da', rawBody: big);
      expect(response.statusCode, 413);
      expect(row('tra-da'), before);
    });

    test('the token is checked before the body is read', () async {
      final big = 'x' * (maxMenuEditBytes * 2);
      final response = await patch(
        staff,
        'tra-da',
        rawBody: big,
        sentToken: null,
      );
      expect(response.statusCode, 401);
    });

    test('DELETE /menu/{id} is still not served', () async {
      for (final (method, path) in [('DELETE', '/menu/tra-da')]) {
        final response = await Future.sync(
          () => staff(
            Request(
              method,
              Uri.parse('http://localhost$path'),
              headers: staffCreds(token),
            ),
          ),
        );
        expect(response.statusCode, isNot(200), reason: method);
      }
      expect(row('tra-da')['available'], 1);
    });

    test('no response ever contains the token', () async {
      final responses = [
        await patch(staff, 'tra-da', body: {'price': 4000}),
        await patch(staff, 'tra-da', body: {}),
        await patch(staff, 'nope', body: {'price': 1}),
        await patch(staff, 'tra-da', body: {'price': 1}, sentToken: 'bad'),
      ];
      for (final response in responses) {
        expect(response.headers.values.join(' '), isNot(contains(token)));
        expect(await response.readAsString(), isNot(contains(token)));
      }
    });
  });

  group('GET /toppings', () {
    test('returns the toppings as JSON, in order', () async {
      final response = await call(handler, 'GET', '/toppings');

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(await response.readAsString()), seedToppings);
    });

    test('reflects a change made directly in SQL (no caching)', () async {
      db.execute("UPDATE toppings SET price = 11000 WHERE id = 'cha'");

      final response = await call(handler, 'GET', '/toppings');
      final toppings = (jsonDecode(await response.readAsString()) as List)
          .cast<Map<String, dynamic>>();

      expect(toppings.firstWhere((t) => t['id'] == 'cha')['price'], 11000);
    });

    for (final method in ['POST', 'PATCH', 'PUT', 'DELETE']) {
      test('$method /toppings is not allowed', () async {
        final response = await call(handler, method, '/toppings');

        expect(response.statusCode, isNot(200));
      });
    }
  });

  group('persistence', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('menu_db_test');
      dbPath = '${tempDir.path}/orders.db';
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('edits survive reopening; the seed does not run again', () async {
      final first = openDatabase(dbPath);
      first.execute("DELETE FROM menu_items WHERE id = 'tra-da'");
      first.execute(
        "UPDATE menu_items SET price = 31000 WHERE id = 'mi-tom-bo'",
      );
      first.execute(
        "INSERT INTO orders VALUES ('1', 'Alice', 'preparing', "
        "'2026-10-30T12:00:00.000', '[]', NULL, NULL)",
      );
      first.close();

      final reopened = openDatabase(dbPath);
      addTearDown(reopened.close);
      final menu = (await getMenu(MenuApi(reopened).handler))
          .cast<Map<String, dynamic>>();

      expect(menu.map((i) => i['id']), isNot(contains('tra-da')));
      expect(menu, hasLength(seedMenu.length - 1));
      expect(menu.firstWhere((i) => i['id'] == 'mi-tom-bo')['price'], 31000);
      expect(reopened.select('SELECT id FROM orders'), hasLength(1));
    });
  });
}

/// The test staff ID; the password is the test's `token` value.
const testStaffId = 'test-staff';

/// Staff headers for [password] (none when null), with the test staff ID.
Map<String, String> staffCreds(String? password) => password == null
    ? const {}
    : {staffIdHeader: testStaffId, staffPasswordHeader: password};
