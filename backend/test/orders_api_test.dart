import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/no_sniff.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const staffHeaders = {
  'x-staff-id': 'test-staff',
  'x-staff-password': 'staff-password-for-tests-1234',
};

StaffGate testGate() =>
    StaffGate(id: 'test-staff', password: 'staff-password-for-tests-1234');

/// Same shape as `Order.toJson()` in lib/shared/models/order.dart.
Map<String, dynamic> sampleOrder(String id) => {
  'id': id,
  'customerName': 'Alice',
  'items': [
    {'name': 'Pho', 'quantity': 2, 'price': 9.5},
  ],
  'status': 'preparing',
  'placedAt': '2026-10-30T12:00:00.000',
};

/// What the API returns for an order posted without a payment method.
Map<String, dynamic> stored(Map<String, dynamic> order) => {
  ...order,
  'paymentMethod': 'cash',
  'paymentDueAt': null,
};

/// Request bodies that are not a JSON object. POST and PATCH must reject
/// each one with 400.
const badBodies = [
  ('invalid JSON', '{not json'),
  ('a JSON list', '[1, 2]'),
  ('a JSON string', '"hello"'),
  ('an empty body', ''),
];

void main() {
  late Database db;
  late OrdersApi api;
  late Handler handler;

  setUp(() {
    db = openDatabase(':memory:');
    api = OrdersApi(db, staffGate: testGate());
    handler = api.handler;
  });

  tearDown(() async {
    await api.close();
    db.close();
  });

  Future<Response> send(String method, String path, {Object? body}) {
    return Future.sync(
      () => handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: staffHeaders,
          body: body is String
              ? body
              : (body == null ? null : jsonEncode(body)),
        ),
      ),
    );
  }

  Future<Object?> readJson(Response response) async =>
      jsonDecode(await response.readAsString());

  Future<List<Object?>> listOrders() async =>
      (await readJson(await send('GET', '/orders'))) as List<Object?>;

  group('limits (backend-request-body-limit)', () {
    /// Inserts [n] orders straight into the table, fast, in one transaction.
    void storeOrders(int n) {
      db.execute('BEGIN');
      final insert = db.prepare(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
        "VALUES (?, 'Bulk', 'finished', '2026-11-01T08:00:00.000', '[]')",
      );
      for (var i = 0; i < n; i++) {
        insert.execute(['bulk-$i']);
      }
      insert.close();
      db.execute('COMMIT');
    }

    test('GET /orders returns only the newest $maxOrdersReturned', () async {
      storeOrders(maxOrdersReturned + 20);

      final orders = (await listOrders()).cast<Map<String, dynamic>>();

      expect(orders, hasLength(maxOrdersReturned));
      expect(orders.first['id'], 'bulk-${maxOrdersReturned + 19}');
      expect(orders.last['id'], 'bulk-20');
    });

    test('a new order is refused with 503 once storage is full', () async {
      final small = OrdersApi(db, maxStoredOrders: 3);
      addTearDown(small.close);
      Future<Response> post(String id) => Future.sync(
        () => small.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/orders'),
            body: jsonEncode(sampleOrder(id)),
          ),
        ),
      );

      for (final id in ['1', '2', '3']) {
        expect((await post(id)).statusCode, 200);
      }
      final refused = await post('4');

      expect(refused.statusCode, 503);
      expect(await refused.readAsString(), 'Order storage is full');
      expect(db.select('SELECT COUNT(*) AS n FROM orders').first['n'], 3);
    });

    test('the default cap is $defaultMaxStoredOrders', () async {
      storeOrders(defaultMaxStoredOrders);

      final refused = await send('POST', '/orders', body: sampleOrder('new'));

      expect(refused.statusCode, 503);
      expect(
        db.select('SELECT COUNT(*) AS n FROM orders').first['n'],
        defaultMaxStoredOrders,
      );
    });

    test('status changes still work when storage is full', () async {
      storeOrders(defaultMaxStoredOrders);

      final response = await send(
        'PATCH',
        '/orders/bulk-0',
        body: {'status': 'cancelled'},
      );

      expect(response.statusCode, 200);
    });

    final long = 'a' * (maxNameLength + 1);
    final exact = 'a' * maxNameLength;
    Map<String, dynamic> withItem(Map<String, dynamic> item) => {
      ...sampleOrder('1'),
      'items': [item],
    };
    final pho = {'name': 'Pho', 'quantity': 2, 'price': 9.5};

    for (final (label, order) in [
      (
        'a customer name over $maxNameLength',
        {...sampleOrder('1'), 'customerName': long},
      ),
      ('an item name over $maxNameLength', withItem({...pho, 'name': long})),
      (
        'a topping name over $maxNameLength',
        withItem({
          ...pho,
          'toppings': [
            {'name': long, 'price': 1000},
          ],
        }),
      ),
      (
        'quantity ${maxQuantity + 1}',
        withItem({...pho, 'quantity': maxQuantity + 1}),
      ),
      ('quantity 9e18', withItem({...pho, 'quantity': 9000000000000000000})),
      ('price ${maxPrice + 1}', withItem({...pho, 'price': maxPrice + 1})),
      ('price 9e18', withItem({...pho, 'price': 9e18})),
      ('an id over $maxIdLength', sampleOrder('a' * (maxIdLength + 1))),
      (
        'an item id over $maxIdLength',
        withItem({...pho, 'id': 'a' * (maxIdLength + 1)}),
      ),
      (
        '${maxItemsPerOrder + 1} items',
        {...sampleOrder('1'), 'items': List.filled(maxItemsPerOrder + 1, pho)},
      ),
      (
        'topping price ${maxPrice + 1}',
        withItem({
          ...pho,
          'toppings': [
            {'name': 'Thêm chả', 'price': maxPrice + 1},
          ],
        }),
      ),
    ]) {
      test('$label -> 400, nothing stored', () async {
        final response = await send('POST', '/orders', body: order);

        expect(response.statusCode, 400);
        expect(await response.readAsString(), isNot(contains('aaaa')));
        expect(await listOrders(), isEmpty);
      });
    }

    test('the exact limits are accepted', () async {
      final response = await send(
        'POST',
        '/orders',
        body: {
          ...sampleOrder('1'),
          'id': 'i' * maxIdLength,
          'customerName': exact,
          'items': [
            ...List.filled(maxItemsPerOrder - 1, pho),
            {
              'name': exact,
              'quantity': maxQuantity,
              'price': maxPrice,
              'toppings': [
                {'name': exact, 'price': maxPrice},
              ],
            },
          ],
        },
      );

      expect(response.statusCode, 200);
    });

    test('noSniff adds nosniff to plain-text errors and JSON', () async {
      final guarded = const Pipeline()
          .addMiddleware(noSniff())
          .addHandler(handler);
      Future<Response> call(String method, String path, [Object? body]) =>
          Future.sync(
            () => guarded(
              Request(
                method,
                Uri.parse('http://localhost$path'),
                headers: staffHeaders,
                body: body == null ? null : jsonEncode(body),
              ),
            ),
          );

      final bad = await call('POST', '/orders', {'nope': 1});
      final missing = await call('PATCH', '/orders/x', {'status': 'finished'});
      final ok = await call('GET', '/orders');

      expect(bad.statusCode, 400);
      expect(missing.statusCode, 404);
      for (final response in [bad, missing, ok]) {
        expect(response.headers['x-content-type-options'], 'nosniff');
      }
    });
  });

  group('GET /orders', () {
    test('returns an empty JSON list on a fresh instance', () async {
      final response = await send('GET', '/orders');

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'application/json');
      expect(await readJson(response), isEmpty);
    });
  });

  group('POST /orders', () {
    test('echoes the order and stores it', () async {
      final response = await send('POST', '/orders', body: sampleOrder('1'));

      expect(response.statusCode, 200);
      expect(await readJson(response), stored(sampleOrder('1')));
      expect(await listOrders(), [stored(sampleOrder('1'))]);
    });

    test('lists orders newest first', () async {
      await send('POST', '/orders', body: sampleOrder('1'));
      await send('POST', '/orders', body: sampleOrder('2'));

      final ids = (await listOrders()).map((o) => (o as Map)['id']);
      expect(ids, ['2', '1']);
    });

    for (final (label, body) in badBodies) {
      test('rejects $label with 400 and stores nothing', () async {
        final response = await send('POST', '/orders', body: body);

        expect(response.statusCode, 400);
        expect(await listOrders(), isEmpty);
      });
    }
  });

  group('POST /orders validation', () {
    Map<String, dynamic> withItem(Map<String, dynamic> item) => {
      ...sampleOrder('1'),
      'items': [item],
    };

    for (final field in ['id', 'customerName', 'items', 'status', 'placedAt']) {
      test('rejects an order missing $field', () async {
        final order = sampleOrder('1')..remove(field);

        final response = await send('POST', '/orders', body: order);

        expect(response.statusCode, 400);
        expect(await listOrders(), isEmpty);
      });
    }

    for (final (label, order) in [
      ('an unknown top-level field', {...sampleOrder('1'), 'admin': true}),
      ('an empty id', {...sampleOrder('1'), 'id': ''}),
      ('a numeric id', {...sampleOrder('1'), 'id': 1}),
      ('a numeric customerName', {...sampleOrder('1'), 'customerName': 5}),
      ('an unknown status', {...sampleOrder('1'), 'status': 'shipped'}),
      ('a non-date placedAt', {...sampleOrder('1'), 'placedAt': 'yesterday'}),
      ('items that are not a list', {...sampleOrder('1'), 'items': 'pho'}),
      ('an empty items list', {...sampleOrder('1'), 'items': []}),
      (
        'an item that is not an object',
        {
          ...sampleOrder('1'),
          'items': ['pho'],
        },
      ),
      (
        'an item with an unknown field',
        withItem({'name': 'Pho', 'quantity': 1, 'price': 9.5, 'note': 'x'}),
      ),
      ('an item missing price', withItem({'name': 'Pho', 'quantity': 1})),
      (
        'a fractional quantity',
        withItem({'name': 'Pho', 'quantity': 1.5, 'price': 9.5}),
      ),
      (
        'a string price',
        withItem({'name': 'Pho', 'quantity': 1, 'price': '9.5'}),
      ),
      (
        'an infinite price (1e999 in JSON)',
        // Sent as raw JSON: jsonEncode can't produce Infinity itself.
        '{"id":"1","customerName":"Alice","status":"preparing",'
            '"placedAt":"2026-10-30T12:00:00.000",'
            '"items":[{"name":"Pho","quantity":1,"price":1e999}]}',
      ),
      (
        'a negative price',
        withItem({'name': 'Pho', 'quantity': 1, 'price': -1}),
      ),
      (
        'a zero quantity',
        withItem({'name': 'Pho', 'quantity': 0, 'price': 9.5}),
      ),
      ('a year-only placedAt', {...sampleOrder('1'), 'placedAt': '2026'}),
      (
        'a compact-date placedAt',
        {...sampleOrder('1'), 'placedAt': '20261030'},
      ),
      (
        'a numeric item name',
        withItem({'name': 7, 'quantity': 1, 'price': 9.5}),
      ),
    ]) {
      test('rejects $label', () async {
        final response = await send('POST', '/orders', body: order);

        expect(response.statusCode, 400);
        expect(await listOrders(), isEmpty);
      });
    }

    test('accepts a whole-number price', () async {
      final order = withItem({'name': 'Tea', 'quantity': 1, 'price': 2});

      final response = await send('POST', '/orders', body: order);

      expect(response.statusCode, 200);
      expect(await listOrders(), [stored(order)]);
    });

    test('rejects a duplicate id with 409 and keeps the original', () async {
      await send('POST', '/orders', body: sampleOrder('1'));

      final response = await send(
        'POST',
        '/orders',
        body: {...sampleOrder('1'), 'customerName': 'Mallory'},
      );

      expect(response.statusCode, 409);
      expect(await listOrders(), [stored(sampleOrder('1'))]);
    });
  });

  group('order items with toppings', () {
    Map<String, dynamic> orderWithItem(Map<String, Object?> item) => {
      ...sampleOrder('t1'),
      'items': [item],
    };

    const xoi = {'name': 'Xôi thịt', 'quantity': 1, 'price': 25000};

    test('accepts toppings, echoes them and stores them', () async {
      final order = orderWithItem({
        ...xoi,
        'toppings': [
          {'name': 'Thêm chả', 'price': 10000},
          {'name': 'Thêm trứng tráng', 'price': 8000},
        ],
      });

      final response = await send('POST', '/orders', body: order);

      expect(response.statusCode, 200);
      expect(await readJson(response), stored(order));
      expect(await listOrders(), [stored(order)]);
    });

    test('accepts an empty toppings list and no toppings at all', () async {
      final empty = orderWithItem({...xoi, 'toppings': <Object>[]});
      final none = {...orderWithItem(xoi), 'id': 't2'};

      expect((await send('POST', '/orders', body: empty)).statusCode, 200);
      expect((await send('POST', '/orders', body: none)).statusCode, 200);
      expect(await listOrders(), [stored(none), stored(empty)]);
    });

    test('accepts ids on items and toppings, and keeps them', () async {
      final order = orderWithItem({
        ...xoi,
        'id': 'xoi-thit',
        'toppings': [
          {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
        ],
      });

      final response = await send('POST', '/orders', body: order);

      expect(response.statusCode, 200);
      expect(await listOrders(), [stored(order)]);
    });

    test('a drink is just another line, no special field', () async {
      final order = {
        ...sampleOrder('t3'),
        'items': [
          {...xoi, 'id': 'xoi-thit'},
          {'id': 'tra-da', 'name': 'Trà đá', 'quantity': 2, 'price': 4000},
        ],
      };

      expect((await send('POST', '/orders', body: order)).statusCode, 200);
    });

    // Allowed on purpose: two portions of the same extra.
    test('accepts the same topping twice on one line', () async {
      final order = orderWithItem({
        ...xoi,
        'toppings': [
          {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
          {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
        ],
      });

      expect((await send('POST', '/orders', body: order)).statusCode, 200);
      expect(await listOrders(), [stored(order)]);
    });

    test('accepts exactly $maxToppingsPerItem toppings', () async {
      final order = orderWithItem({
        ...xoi,
        'toppings': [
          for (var i = 0; i < maxToppingsPerItem; i++)
            {'name': 'Topping $i', 'price': 1000},
        ],
      });

      expect((await send('POST', '/orders', body: order)).statusCode, 200);
    });

    test('an order stored in the old shape still reads back unchanged', () async {
      final oldItems = [xoi];
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
        'VALUES (?, ?, ?, ?, ?)',
        [
          'old',
          'Bao',
          'pending',
          '2026-11-01T08:00:00.000',
          jsonEncode(oldItems),
        ],
      );

      final orders = (await listOrders()).cast<Map<String, dynamic>>();

      expect(orders.single['items'], oldItems);
    });

    for (final (label, item) in <(String, Map<String, Object?>)>[
      ('toppings that are not a list', {...xoi, 'toppings': 'chả'}),
      ('null toppings', {...xoi, 'toppings': null}),
      (
        'a topping that is a string',
        {
          ...xoi,
          'toppings': ['chả'],
        },
      ),
      (
        'a topping with an extra key',
        {
          ...xoi,
          'toppings': [
            {'name': 'Thêm chả', 'price': 10000, 'note': 'x'},
          ],
        },
      ),
      (
        'a topping missing its name',
        {
          ...xoi,
          'toppings': [
            {'price': 10000},
          ],
        },
      ),
      (
        'a topping missing its price',
        {
          ...xoi,
          'toppings': [
            {'name': 'Thêm chả'},
          ],
        },
      ),
      ('an empty item id', {...xoi, 'id': ''}),
      ('a numeric item id', {...xoi, 'id': 7}),
      (
        'an empty topping id',
        {
          ...xoi,
          'toppings': [
            {'id': '', 'name': 'Thêm chả', 'price': 10000},
          ],
        },
      ),
      (
        'a numeric topping id',
        {
          ...xoi,
          'toppings': [
            {'id': 1, 'name': 'Thêm chả', 'price': 10000},
          ],
        },
      ),
      (
        'a negative topping price',
        {
          ...xoi,
          'toppings': [
            {'name': 'Thêm chả', 'price': -1},
          ],
        },
      ),
      (
        'a string topping price',
        {
          ...xoi,
          'toppings': [
            {'name': 'Thêm chả', 'price': '10000'},
          ],
        },
      ),
      (
        'more than $maxToppingsPerItem toppings',
        {
          ...xoi,
          'toppings': [
            for (var i = 0; i <= maxToppingsPerItem; i++)
              {'name': 'Topping $i', 'price': 1000},
          ],
        },
      ),
      ('an unknown extra key on the item', {...xoi, 'note': 'ít hành'}),
    ]) {
      test('rejects $label with 400 and stores nothing', () async {
        final response = await send(
          'POST',
          '/orders',
          body: orderWithItem(item),
        );

        expect(response.statusCode, 400);
        expect(await listOrders(), isEmpty);
        final body = await response.readAsString();
        expect(body, isNot(contains('chả')), reason: 'no request text echoed');
        expect(body, isNot(contains('ít hành')));
      });
    }

    test('rejects an infinite topping price (1e999 in JSON)', () async {
      final response = await send(
        'POST',
        '/orders',
        body:
            '{"id":"t9","customerName":"Bao","status":"preparing",'
            '"placedAt":"2026-11-12T12:00:00.000",'
            '"items":[{"name":"Xôi","quantity":1,"price":25000,'
            '"toppings":[{"name":"Chả","price":1e999}]}]}',
      );

      expect(response.statusCode, 400);
      expect(await listOrders(), isEmpty);
    });
  });

  group('PATCH /orders/<id>', () {
    setUp(() async {
      await send('POST', '/orders', body: sampleOrder('1'));
    });

    test('updates the status and returns the order', () async {
      final response = await send(
        'PATCH',
        '/orders/1',
        body: {'status': 'finished'},
      );

      final expected = {...sampleOrder('1'), 'status': 'finished'};
      expect(response.statusCode, 200);
      expect(await readJson(response), stored(expected));
      expect(await listOrders(), [stored(expected)]);
    });

    test('changes only status, ignoring every other field', () async {
      final response = await send(
        'PATCH',
        '/orders/1',
        body: {
          'status': 'finished',
          'id': 'other',
          'customerName': 'x',
          'items': [],
        },
      );

      final expected = {...sampleOrder('1'), 'status': 'finished'};
      expect(response.statusCode, 200);
      expect(await readJson(response), stored(expected));
      expect(await listOrders(), [stored(expected)]);
    });

    for (final (label, body) in [
      ('a body without status', {'customerName': 'x'}),
      ('an unknown status', {'status': 'shipped'}),
      ('a non-string status', {'status': 1}),
    ]) {
      test('rejects $label with 400 and leaves the order unchanged', () async {
        final response = await send('PATCH', '/orders/1', body: body);

        expect(response.statusCode, 400);
        expect(await listOrders(), [stored(sampleOrder('1'))]);
      });
    }

    test('checks the status before looking up the id', () async {
      final response = await send(
        'PATCH',
        '/orders/missing',
        body: {'status': 'shipped'},
      );

      expect(response.statusCode, 400);
    });

    test('returns 404 for an unknown id', () async {
      final response = await send(
        'PATCH',
        '/orders/missing',
        body: {'status': 'finished'},
      );

      expect(response.statusCode, 404);
      expect(await listOrders(), [stored(sampleOrder('1'))]);
    });

    for (final (label, body) in badBodies) {
      test('rejects $label with 400 and leaves the order unchanged', () async {
        final response = await send('PATCH', '/orders/1', body: body);

        expect(response.statusCode, 400);
        expect(await listOrders(), [stored(sampleOrder('1'))]);
      });
    }
  });

  test('separate instances do not share state', () async {
    await send('POST', '/orders', body: sampleOrder('1'));

    final otherDb = openDatabase(':memory:');
    addTearDown(otherDb.close);
    final other = OrdersApi(otherDb);
    addTearDown(other.close);
    final response = await other.handler(
      Request('GET', Uri.parse('http://localhost/orders')),
    );
    expect(jsonDecode(await response.readAsString()), isEmpty);
  });

  group('SQLite storage', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('orders_db_test');
      dbPath = '${tempDir.path}/orders.db';
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    Future<Response> sendTo(
      OrdersApi api,
      String method,
      String path, {
      Object? body,
    }) {
      return Future.sync(
        () => api.handler(
          Request(
            method,
            Uri.parse('http://localhost$path'),
            headers: staffHeaders,
            body: body == null ? null : jsonEncode(body),
          ),
        ),
      );
    }

    test('orders and status changes survive closing and reopening', () async {
      final firstDb = openDatabase(dbPath);
      final first = OrdersApi(firstDb, staffGate: testGate());
      await sendTo(first, 'POST', '/orders', body: sampleOrder('1'));
      await sendTo(first, 'POST', '/orders', body: sampleOrder('2'));
      await sendTo(first, 'PATCH', '/orders/1', body: {'status': 'finished'});
      await first.close();
      firstDb.close();

      final reopenedDb = openDatabase(dbPath);
      addTearDown(reopenedDb.close);
      final reopened = OrdersApi(reopenedDb, staffGate: testGate());
      addTearDown(reopened.close);
      final response = await sendTo(reopened, 'GET', '/orders');

      expect(jsonDecode(await response.readAsString()), [
        stored(sampleOrder('2')),
        stored({...sampleOrder('1'), 'status': 'finished'}),
      ]);
    });

    // Was 1, then 2 (menu_items), 3 (categories and toppings), 4 (the
    // nibble category), 5 (menu pictures), 6 (sold out), 7 and 8 (payment), now 9 (finished).
    test('a fresh file gets user_version 9', () {
      final fileDb = openDatabase(dbPath);
      addTearDown(fileDb.close);

      expect(fileDb.userVersion, 9);
    });

    test('reopening does not re-run the migration or lose data', () async {
      final firstDb = openDatabase(dbPath);
      final first = OrdersApi(firstDb, staffGate: testGate());
      await sendTo(first, 'POST', '/orders', body: sampleOrder('1'));
      await first.close();
      firstDb.close();

      final reopenedDb = openDatabase(dbPath);
      addTearDown(reopenedDb.close);
      expect(reopenedDb.userVersion, 9);
      expect(reopenedDb.select('SELECT id FROM orders').length, 1);
    });

    test('creates the parent directory if it is missing', () {
      final nested = '${tempDir.path}/a/b/orders.db';

      openDatabase(nested).close();

      expect(File(nested).existsSync(), isTrue);
    });
  });

  test('SQL-looking text in an order is stored as plain text', () async {
    final order = {
      ...sampleOrder('1'),
      'customerName': "Robert'); DROP TABLE orders;--",
      'items': [
        {'name': '"Pho" \'special\'', 'quantity': 1, 'price': 9.5},
      ],
    };

    await send('POST', '/orders', body: order);
    await send('POST', '/orders', body: sampleOrder('2'));

    expect(await listOrders(), [stored(sampleOrder('2')), stored(order)]);
  });

  // SSE uses request.hijack(), which only works on a real socket — so this
  // group starts a loopback server on a free port instead of calling the
  // handler directly.
  group('GET /orders/stream (SSE)', () {
    late HttpServer server;
    late HttpClient client;
    late Uri base;

    setUp(() async {
      server = await io.serve(handler, InternetAddress.loopbackIPv4, 0);
      client = HttpClient();
      base = Uri.parse('http://${server.address.host}:${server.port}');
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    test('opens with a comment, then pushes each new order', () async {
      final request = await client.getUrl(base.resolve('/orders/stream'));
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'text/event-stream');

      // SSE frames end with a blank line. Collect frames as they arrive.
      final frames = StreamIterator(
        response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .where((line) => line.isNotEmpty),
      );
      Future<String> nextFrame() async {
        final hasNext = await frames.moveNext().timeout(
          const Duration(seconds: 5),
        );
        expect(hasNext, isTrue, reason: 'stream closed early');
        return frames.current;
      }

      expect(await nextFrame(), ': connected');

      final post = await client.postUrl(base.resolve('/orders'));
      post.headers.contentType = ContentType.json;
      post.write(jsonEncode(sampleOrder('42')));
      final postResponse = await post.close();
      await postResponse.drain<void>();
      expect(postResponse.statusCode, 200);

      final frame = await nextFrame();
      expect(frame, startsWith('data: '));
      expect(
        jsonDecode(frame.substring('data: '.length)),
        stored(sampleOrder('42')),
      );

      await frames.cancel();
    });
  });
}
