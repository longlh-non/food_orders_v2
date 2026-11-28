import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/orders_export.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

// Obviously fake bank details.
const _bankEnv = <String, String?>{
  'BANK_BIN': '000000',
  'BANK_ACCOUNT': '1234567890',
  'BANK_ACCOUNT_NAME': 'LE VAN HUNG',
  'BANK_NAME': 'Ngan hang Thu',
};

const _staffId = 'test-staff';
const _staffPassword = 'staff-password-for-tests-1234';
const _staff = {'x-staff-id': _staffId, 'x-staff-password': _staffPassword};

Map<String, dynamic> _order(String id, {Map<String, dynamic>? extra}) => {
  'id': id,
  'customerName': 'Alice',
  'items': [
    {'name': 'Xôi thịt', 'quantity': 2, 'price': 25000},
  ],
  'status': 'preparing',
  'placedAt': '2026-11-19T12:00:00.000',
  ...?extra,
};

Map<String, dynamic> _transfer(String id) => _order(
  id,
  extra: {'paymentMethod': 'bank_transfer', 'status': 'awaiting_payment'},
);

void main() {
  late Database db;
  late OrdersApi api;
  final clock = DateTime.utc(2026, 11, 19, 8, 0);

  void open({Map<String, String?> env = _bankEnv}) {
    db = openDatabase(':memory:');
    api = OrdersApi(
      db,
      shopSettings: ShopSettings(env),
      now: () => clock,
      staffGate: StaffGate(id: _staffId, password: _staffPassword),
    );
  }

  setUp(open);

  tearDown(() async {
    await api.close();
    db.close();
  });

  Future<Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => Future.sync(
    () => api.handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        // PATCH is a staff route now: send the staff proof with it.
        headers: method == 'PATCH' ? {..._staff, ...?headers} : headers,
        body: body is String || body == null ? body : jsonEncode(body),
      ),
    ),
  );

  Future<dynamic> json(Response r) async => jsonDecode(await r.readAsString());
  Future<List> list() async =>
      (await json(await send('GET', '/orders'))) as List;

  group('POST payment rules', () {
    test('cash + preparing, and no method + preparing, are cash', () async {
      final a = await send(
        'POST',
        '/orders',
        body: _order('a', extra: {'paymentMethod': 'cash'}),
      );
      final b = await send('POST', '/orders', body: _order('b'));
      for (final r in [a, b]) {
        expect(r.statusCode, 200);
        final order = await json(r) as Map;
        expect(order['paymentMethod'], 'cash');
        expect(order['paymentDueAt'], isNull);
        expect(order.containsKey('paymentDueAt'), isTrue);
      }
    });

    test(
      'bank_transfer + awaiting_payment: deadline = server clock + 5 min',
      () async {
        final r = await send('POST', '/orders', body: _transfer('t'));
        expect(r.statusCode, 200);
        final order = await json(r) as Map;
        expect(order['paymentMethod'], 'bank_transfer');
        expect(order['status'], 'awaiting_payment');
        expect(order['paymentDueAt'], '2026-11-19T08:05:00.000Z');
        expect((await list()).single, order);
      },
    );

    test('the deadline is cut to whole milliseconds', () async {
      final micro = OrdersApi(
        db,
        shopSettings: ShopSettings(_bankEnv),
        now: () => DateTime.utc(2026, 11, 19, 8, 0, 0, 123, 456),
      );
      addTearDown(micro.close);
      final r = await micro.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/orders'),
          body: jsonEncode(_transfer('m')),
        ),
      );
      expect((await json(r))['paymentDueAt'], '2026-11-19T08:05:00.123Z');
    });

    test('the deadline follows the injected clock, not the placedAt', () async {
      final late = OrdersApi(
        db,
        shopSettings: ShopSettings(_bankEnv),
        now: () => DateTime.utc(2030, 1, 1, 0, 0),
      );
      addTearDown(late.close);
      final r = await late.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/orders'),
          body: jsonEncode(_transfer('t')),
        ),
      );
      expect((await json(r))['paymentDueAt'], '2030-01-01T00:05:00.000Z');
    });

    for (final (label, extra) in [
      (
        'paymentDueAt in the body',
        {'paymentDueAt': '2030-01-01T00:00:00.000Z'},
      ),
      ('paymentDueAt null in the body', {'paymentDueAt': null}),
      ('paymentMethod "card"', {'paymentMethod': 'card'}),
      ('paymentMethod 5', {'paymentMethod': 5}),
      ('paymentMethod null', {'paymentMethod': null}),
      ('paymentMethod "CASH"', {'paymentMethod': 'CASH'}),
      (
        'cash + awaiting_payment',
        {'paymentMethod': 'cash', 'status': 'awaiting_payment'},
      ),
      ('no method + awaiting_payment', {'status': 'awaiting_payment'}),
      (
        'bank_transfer + preparing',
        {'paymentMethod': 'bank_transfer', 'status': 'preparing'},
      ),
      ('status pending', {'status': 'pending'}),
      ('status accepted', {'status': 'accepted'}),
      (
        'bank_transfer + pending',
        {'paymentMethod': 'bank_transfer', 'status': 'pending'},
      ),
      (
        'bank_transfer + ready',
        {'paymentMethod': 'bank_transfer', 'status': 'ready'},
      ),
      ('cash + delivered', {'status': 'delivered'}),
    ]) {
      test('$label -> 400, nothing stored, no echo', () async {
        final r = await send(
          'POST',
          '/orders',
          body: _order('x', extra: extra),
        );
        expect(r.statusCode, 400);
        final text = await r.readAsString();
        expect(text, isNot(contains('2030')));
        expect(text, isNot(contains('card')));
        expect(await list(), isEmpty);
      });
    }

    test('bank_transfer with a total of 0 -> 400', () async {
      final r = await send(
        'POST',
        '/orders',
        body: {
          ..._transfer('free'),
          'items': [
            {'name': 'Free', 'quantity': 1, 'price': 0},
          ],
        },
      );
      expect(r.statusCode, 400);
      expect(await list(), isEmpty);
    });

    test('bank_transfer: a topping makes the total above 0', () async {
      final r = await send(
        'POST',
        '/orders',
        body: {
          ..._transfer('tp'),
          'items': [
            {
              'name': 'Free',
              'quantity': 1,
              'price': 0,
              'toppings': [
                {'name': 'Thêm chả', 'price': 10000},
              ],
            },
          ],
        },
      );
      expect(r.statusCode, 200);
    });

    test('cash with a total of 0 is still allowed', () async {
      final r = await send(
        'POST',
        '/orders',
        body: {
          ..._order('free'),
          'items': [
            {'name': 'Free', 'quantity': 1, 'price': 0},
          ],
        },
      );
      expect(r.statusCode, 200);
    });

    test(
      'bank_transfer with bank settings disabled -> 503, nothing stored',
      () async {
        await api.close();
        db.close();
        open(env: {..._bankEnv, 'BANK_BIN': null});
        final r = await send('POST', '/orders', body: _transfer('t'));
        expect(r.statusCode, 503);
        expect(await r.readAsString(), 'Bank transfer is not set up');
        expect(await list(), isEmpty);
      },
    );

    test(
      'a default OrdersApi (no settings) treats transfer as not set up',
      () async {
        final plain = OrdersApi(db);
        addTearDown(plain.close);
        final r = await plain.handler(
          Request(
            'POST',
            Uri.parse('http://localhost/orders'),
            body: jsonEncode(_transfer('t')),
          ),
        );
        expect(r.statusCode, 503);
      },
    );

    test(
      'a 400 wins over a 503 when the transfer order is also invalid',
      () async {
        await api.close();
        db.close();
        open(env: {});
        final r = await send(
          'POST',
          '/orders',
          body: _order('x', extra: {'paymentMethod': 'bank_transfer'}),
        );
        expect(r.statusCode, 400);
      },
    );
  });

  group('reading back', () {
    test('an order stored by the old code reads back cash / null', () async {
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
        "VALUES ('old', 'Bao', 'finished', '2026-10-01T10:00:00.000', '[]')",
      );
      final order = (await list()).single as Map;
      expect(order['paymentMethod'], 'cash');
      expect(order['paymentDueAt'], isNull);
      final raw = db.select('SELECT payment_method FROM orders').single;
      expect(raw['payment_method'], isNull, reason: 'nothing is rewritten');
    });

    test('the database refuses an unknown payment_method', () {
      expect(
        () => db.execute(
          'INSERT INTO orders (id, customer_name, status, placed_at, '
          "items_json, payment_method) VALUES ('x', 'a', 'preparing', "
          "'2026-10-01T10:00:00.000', '[]', 'card')",
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('the SSE event carries both fields', () async {
      final server = await io.serve(
        api.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.getUrl(
        Uri.parse('http://localhost:${server.port}/orders/stream'),
      );
      final response = await request.close();
      final frames = StreamController<String>();
      response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(frames.add, onDone: frames.close);
      final iterator = StreamIterator(frames.stream);
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, ': connected');

      await send('POST', '/orders', body: _transfer('sse'));
      String data = '';
      while (await iterator.moveNext()) {
        if (iterator.current.startsWith('data: ')) {
          data = iterator.current.substring(6);
          break;
        }
      }
      final event = jsonDecode(data) as Map;
      expect(event['paymentMethod'], 'bank_transfer');
      expect(event['paymentDueAt'], '2026-11-19T08:05:00.000Z');
      await iterator.cancel();
    });
  });

  group('PATCH and payment', () {
    Future<Response> patch(String id, String status) =>
        send('PATCH', '/orders/$id', body: {'status': status});

    test(
      'awaiting_payment -> cancelled is 200 and clears paymentDueAt',
      () async {
        await send('POST', '/orders', body: _transfer('t'));
        final r = await patch('t', 'cancelled');
        expect(r.statusCode, 200);
        final order = await json(r) as Map;
        expect(order['status'], 'cancelled');
        expect(order['paymentDueAt'], isNull);
        expect(order['paymentMethod'], 'bank_transfer');
      },
    );

    for (final target in ['preparing', 'finished']) {
      test('awaiting_payment -> $target is 200, clears the deadline', () async {
        await send('POST', '/orders', body: _transfer('t'));
        final r = await patch('t', target);
        expect(r.statusCode, 200);
        final order = await json(r) as Map;
        expect(order['status'], target);
        expect(order['paymentMethod'], 'bank_transfer');
        expect(order['paymentDueAt'], isNull);
      });
    }

    test('a transfer order already awaiting_payment: same status is a no-op '
        '200', () async {
      await send('POST', '/orders', body: _transfer('t'));
      final r = await patch('t', 'awaiting_payment');
      expect(r.statusCode, 200);
      final order = (await list()).single as Map;
      expect(order['status'], 'awaiting_payment');
      expect(order['paymentDueAt'], '2026-11-19T08:05:00.000Z');
    });

    test(
      'a transfer order can not be PATCHed back to awaiting_payment',
      () async {
        await send('POST', '/orders', body: _transfer('t'));
        await patch('t', 'preparing');
        final r = await patch('t', 'awaiting_payment');
        expect(r.statusCode, 409);
        expect(await r.readAsString(), 'Use the payment routes');
        expect(((await list()).single as Map)['status'], 'preparing');
      },
    );

    test('preparing -> finished -> preparing works', () async {
      await send('POST', '/orders', body: _order('c'));
      for (final s in ['finished', 'preparing']) {
        final r = await patch('c', s);
        expect(r.statusCode, 200);
        expect((await json(r))['status'], s);
      }
    });

    test('pending, accepted, ready, delivered are not statuses (400); unknown '
        'id 404', () async {
      await send('POST', '/orders', body: _order('c'));
      for (final s in ['pending', 'accepted', 'ready', 'delivered']) {
        expect((await patch('c', s)).statusCode, 400, reason: s);
      }
      expect((await patch('nope', 'finished')).statusCode, 404);
      expect((await patch('nope', 'awaiting_payment')).statusCode, 404);
    });

    test('a cash order cancelled keeps paymentDueAt null', () async {
      await send('POST', '/orders', body: _order('c'));
      final order = await json(await patch('c', 'cancelled')) as Map;
      expect(order['paymentDueAt'], isNull);
    });

    test(
      'a cancelled bank_transfer order cannot leave cancelled (409)',
      () async {
        await send('POST', '/orders', body: _transfer('t'));
        expect((await patch('t', 'cancelled')).statusCode, 200);
        final before = db.select('SELECT * FROM orders').single;
        for (final target in ['preparing', 'finished', 'awaiting_payment']) {
          final r = await patch('t', target);
          expect(r.statusCode, 409, reason: target);
          expect(await r.readAsString(), 'Use the payment routes');
        }
        expect(db.select('SELECT * FROM orders').single, before);
      },
    );

    test('an expiry-cancelled row cannot leave cancelled; a staff cancel '
        'clears its deadline', () async {
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json, '
        'payment_method, payment_due_at) VALUES (\'e\', \'A\', \'cancelled\', '
        '\'2026-11-19T12:00:00.000\', \'[]\', \'bank_transfer\', '
        '\'2026-11-19T08:05:00.000Z\')',
      );
      expect((await patch('e', 'preparing')).statusCode, 409);
      var row = db.select('SELECT * FROM orders').single;
      expect(row['status'], 'cancelled');
      expect(row['payment_due_at'], '2026-11-19T08:05:00.000Z');
      // Cancelling again is a real staff cancel (owner, option A).
      expect((await patch('e', 'cancelled')).statusCode, 200);
      row = db.select('SELECT * FROM orders').single;
      expect(row['status'], 'cancelled');
      expect(row['payment_due_at'], isNull);
    });

    test(
      'a cancelled cash order can no longer be PATCHed back (409)',
      () async {
        await send('POST', '/orders', body: _order('c'));
        await patch('c', 'cancelled');
        final r = await patch('c', 'preparing');
        expect(r.statusCode, 409);
        expect(await r.readAsString(), "A cancelled order can't be changed");
      },
    );
  });

  group('migration', () {
    test('a fresh database reaches version 9', () {
      expect(db.userVersion, 9);
    });

    test(
      'version 6 -> 9 keeps every row; pending/accepted/delivered change',
      () {
        final v6 = openDatabase(':memory:');
        addTearDown(v6.close);
        v6.execute('ALTER TABLE orders DROP COLUMN payment_method');
        v6.execute('ALTER TABLE orders DROP COLUMN payment_due_at');
        v6.userVersion = 6;
        const statuses = [
          'pending',
          'accepted',
          'preparing',
          'delivered',
          'cancelled',
        ];
        for (final (i, s) in statuses.indexed) {
          v6.execute('INSERT INTO orders VALUES (?, ?, ?, ?, ?)', [
            'o$i',
            'Bao',
            s,
            '2026-11-0${i + 1}T09:00:00.000',
            '[]',
          ]);
        }

        migrate(v6);

        expect(v6.userVersion, 9);
        final rows = v6.select(
          'SELECT id, status, payment_method, payment_due_at FROM orders ORDER BY rowid',
        );
        expect(rows.map((r) => r['id']), ['o0', 'o1', 'o2', 'o3', 'o4']);
        expect(rows.map((r) => r['status']), [
          'preparing',
          'preparing',
          'preparing',
          'finished',
          'cancelled',
        ]);
        expect(rows.every((r) => r['payment_method'] == null), isTrue);
        expect(rows.every((r) => r['payment_due_at'] == null), isTrue);
        migrate(v6);
        expect(v6.select('SELECT id FROM orders'), hasLength(5));
      },
    );
  });

  group('export', () {
    test('the CSV ignores the payment fields', () async {
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
        "VALUES ('old', 'Bao', 'finished', '2026-11-01T09:00:00.000', "
        '\'[{"name":"Trà","quantity":1,"price":4000}]\')',
      );
      await send('POST', '/orders', body: _order('cash1'));
      await send('POST', '/orders', body: _transfer('bank1'));

      final r = await send(
        'GET',
        '/orders/export?month=2026-11',
        headers: {'X-Staff-Id': _staffId, 'X-Staff-Password': _staffPassword},
      );
      expect(r.statusCode, 200);
      final bytes = await r.read().expand((c) => c).toList();

      // The previous output: the same orders without the two new keys.
      List<Map<String, dynamic>> before(List<Map<String, dynamic>> os) => [
        for (final o in os)
          {
            for (final e in o.entries)
              if (!e.key.startsWith('payment')) e.key: e.value,
          },
      ];
      final stored = ((await list()).cast<Map<String, dynamic>>()).reversed
          .toList();
      final golden = csvBytes([
        for (final o in ordersInMonth(before(stored), '2026-11'))
          ...exportRows([o]),
      ]);
      expect(bytes, golden);
      expect(
        utf8.decode(bytes),
        contains(
          '2026-11-19;12:00;bank1;Alice;Xôi thịt;2;25000;;50000;'
          'awaiting_payment\r\n',
        ),
      );
      expect(utf8.decode(bytes), contains('awaiting_payment'));
      expect(utf8.decode(bytes), isNot(contains('bank_transfer')));
    });
  });
}
