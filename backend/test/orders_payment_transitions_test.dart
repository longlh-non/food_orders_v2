import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

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
  var clock = DateTime.utc(2026, 11, 19, 8, 0);
  // The first transfer order placed at 08:00 is due at 08:05.
  final due = DateTime.utc(2026, 11, 19, 8, 5);

  void open({Map<String, String?> env = _bankEnv, StaffGate? gate}) {
    clock = DateTime.utc(2026, 11, 19, 8, 0);
    db = openDatabase(':memory:');
    api = OrdersApi(
      db,
      shopSettings: ShopSettings(env),
      now: () => clock,
      staffGate: gate ?? StaffGate(id: _staffId, password: _staffPassword),
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
        headers: headers,
        body: body is String || body == null ? body : jsonEncode(body),
      ),
    ),
  );

  Future<Map> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map;
  Future<Map> get(String id) async {
    final list =
        jsonDecode(await (await send('GET', '/orders')).readAsString()) as List;
    return list.firstWhere((o) => (o as Map)['id'] == id) as Map;
  }

  Future<void> place(Map<String, dynamic> order) async {
    expect((await send('POST', '/orders', body: order)).statusCode, 200);
  }

  Future<void> expire(String id) async {
    clock = DateTime.utc(2026, 11, 19, 8, 0);
    await place(_transfer(id));
    clock = due;
    expect(api.expireOverdue(), 1);
  }

  Future<Response> customerSwitch(String id) =>
      send('POST', '/orders/$id/switch-to-cash');
  Future<Response> renew(String id) =>
      send('POST', '/orders/$id/renew-payment');
  Future<Response> staffSwitch(String id) =>
      send('POST', '/orders/$id/staff-switch-to-cash', headers: _staff);
  Future<Response> confirm(String id) =>
      send('POST', '/orders/$id/confirm-payment', headers: _staff);

  /// Polls until [done] is true, for at most 2 s (no fixed sleeps).
  Future<void> waitFor(bool Function() done) async {
    final end = DateTime.now().add(const Duration(seconds: 2));
    while (!done() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  String statusOf(String id) =>
      db.select('SELECT status FROM orders WHERE id = ?', [id]).single['status']
          as String;

  Future<void> expectStays(String id, String status) async =>
      expect((await get(id))['status'], status);

  group('expireOverdue', () {
    test(
      '1 ms before the deadline leaves it, at the deadline cancels it',
      () async {
        await place(_transfer('t'));
        clock = due.subtract(const Duration(milliseconds: 1));
        expect(api.expireOverdue(), 0);
        await expectStays('t', 'awaiting_payment');
        clock = due;
        expect(api.expireOverdue(), 1);
        final o = await get('t');
        expect(o['status'], 'cancelled');
        expect(o['paymentDueAt'], '2026-11-19T08:05:00.000Z'); // kept
        expect(api.expireOverdue(), 0);
      },
    );

    test(
      'several at once, one event each; ignores cash, paid, cancelled',
      () async {
        for (final id in ['a', 'b', 'c']) {
          await place(_transfer(id));
        }
        await place(_order('cash'));
        await place(_transfer('paid'));
        expect((await confirm('paid')).statusCode, 200);
        await place(_transfer('staffcancel'));
        await send(
          'PATCH',
          '/orders/staffcancel',
          body: {'status': 'cancelled'},
        );
        clock = due.add(const Duration(hours: 1));
        expect(api.expireOverdue(), 3);
        expect((await get('cash'))['status'], 'preparing');
        expect((await get('paid'))['status'], 'preparing');
        final sc = await get('staffcancel');
        expect(sc['status'], 'cancelled');
        expect(sc['paymentDueAt'], isNull);
      },
    );

    test(
      'an order switched to cash or renewed is not cancelled again',
      () async {
        await place(_transfer('s'));
        await place(_transfer('r'));
        clock = due;
        expect(api.expireOverdue(), 2);
        expect((await customerSwitch('s')).statusCode, 200);
        expect((await renew('r')).statusCode, 200);
        clock = due.add(const Duration(seconds: 1));
        expect(api.expireOverdue(), 0);
        await expectStays('s', 'preparing');
        await expectStays('r', 'awaiting_payment');
      },
    );
  });

  group('sweep with malformed rows', () {
    void insertBad(String id, String dueAt) => db.execute(
      'INSERT INTO orders (id, customer_name, status, placed_at, items_json, '
      "payment_method, payment_due_at) VALUES (?, 'A', 'awaiting_payment', "
      "'2026-11-19T12:00:00.000', 'not json', 'bank_transfer', ?)",
      [id, dueAt],
    );

    test(
      'a due row with broken items_json expires; the others still do',
      () async {
        await place(_transfer('a'));
        insertBad('bad', '2026-11-19T08:01:00.000Z');
        await place(_transfer('z'));
        clock = due;
        expect(api.expireOverdue(), 3);
        for (final id in ['a', 'bad', 'z']) {
          expect(statusOf(id), 'cancelled', reason: id);
        }
      },
    );

    test('a broken row that is not due does not throw', () async {
      insertBad('bad', '2026-11-19T09:00:00.000Z');
      await place(_transfer('a'));
      clock = due;
      expect(api.expireOverdue(), 1);
      expect(statusOf('bad'), 'awaiting_payment');
      expect(statusOf('a'), 'cancelled');
    });

    test('the timer survives a broken row', () async {
      insertBad('bad', '2026-11-19T08:01:00.000Z');
      await place(_transfer('a'));
      clock = due;
      api.startExpirySweep(interval: const Duration(milliseconds: 10));
      await waitFor(
        () => statusOf('a') == 'cancelled' && statusOf('bad') == 'cancelled',
      );
      expect(statusOf('bad'), 'cancelled');
    });
  });

  group('sweep timer', () {
    test('runs on a timer and close() stops it', () async {
      await place(_transfer('t'));
      clock = due;
      api.startExpirySweep(interval: const Duration(milliseconds: 10));
      api.startExpirySweep(interval: const Duration(milliseconds: 10));
      await waitFor(() => statusOf('t') == 'cancelled');
      await expectStays('t', 'cancelled');
      await api.close();
      // A renewed order past its deadline stays untouched: the sweep is off.
      db.execute(
        "UPDATE orders SET status = 'awaiting_payment' WHERE id = 't'",
      );
      // Negative check: nothing to poll for, so one short wait (several ticks).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final row = db.select("SELECT status FROM orders WHERE id = 't'");
      expect(row.single['status'], 'awaiting_payment');
    });
  });

  group('customer switch-to-cash', () {
    test('live order -> cash + preparing, deadline cleared', () async {
      await place(_transfer('t'));
      final r = await customerSwitch('t');
      expect(r.statusCode, 200);
      final o = await json(r);
      expect(o['paymentMethod'], 'cash');
      expect(o['paymentDueAt'], isNull);
      expect(o['status'], 'preparing');
      expect((await customerSwitch('t')).statusCode, 409);
    });

    test('an overdue, not yet swept order is switched', () async {
      await place(_transfer('t'));
      clock = due.add(const Duration(minutes: 1));
      expect((await customerSwitch('t')).statusCode, 200);
    });

    test('expired: ok at +14:59, 409 at +15:01', () async {
      await expire('a');
      clock = due.add(const Duration(minutes: 14, seconds: 59));
      expect((await customerSwitch('a')).statusCode, 200);
      await expire('b');
      clock = due.add(const Duration(minutes: 15, seconds: 1));
      expect((await customerSwitch('b')).statusCode, 409);
      await expectStays('b', 'cancelled');
    });

    test('expired: exactly +15:00 is still inside the window (200)', () async {
      await expire('t');
      clock = due.add(const Duration(minutes: 15));
      expect((await customerSwitch('t')).statusCode, 200);
    });

    test('409 for staff-cancelled, cash, paid; 404 unknown', () async {
      await place(_transfer('sc'));
      await send('PATCH', '/orders/sc', body: {'status': 'cancelled'});
      await place(_order('cash'));
      await place(_transfer('paid'));
      await confirm('paid');
      for (final id in ['sc', 'cash', 'paid']) {
        expect((await customerSwitch(id)).statusCode, 409, reason: id);
      }
      expect((await customerSwitch('nope')).statusCode, 404);
    });
  });

  group('renew-payment', () {
    test(
      'expired at +14:59 -> awaiting_payment, fresh deadline, same order',
      () async {
        await expire('t');
        final before = await get('t');
        clock = due.add(const Duration(minutes: 14, seconds: 59));
        final r = await renew('t');
        expect(r.statusCode, 200);
        final o = await json(r);
        expect(o['status'], 'awaiting_payment');
        expect(o['paymentMethod'], 'bank_transfer');
        expect(
          o['paymentDueAt'],
          clock.add(const Duration(minutes: 5)).toIso8601String(),
        );
        expect(o['items'], before['items']);
        expect(o['id'], 't');
        expect((await renew('t')).statusCode, 409); // live now
      },
    );

    test('exactly +15:00 is still inside the window (200)', () async {
      await expire('t');
      clock = due.add(const Duration(minutes: 15));
      expect((await renew('t')).statusCode, 200);
    });

    test('at +15:01 -> 409 and stays cancelled', () async {
      await expire('t');
      clock = due.add(const Duration(minutes: 15, seconds: 1));
      expect((await renew('t')).statusCode, 409);
      await expectStays('t', 'cancelled');
    });

    test(
      'five renewals in a row, window counts from the latest expiry',
      () async {
        await expire('t');
        for (var i = 0; i < 5; i++) {
          clock = clock.add(const Duration(minutes: 14, seconds: 59));
          final r = await renew('t');
          expect(r.statusCode, 200, reason: 'renewal $i');
          clock = DateTime.parse((await json(r))['paymentDueAt'] as String);
          expect(api.expireOverdue(), 1);
        }
      },
    );

    test('an overdue but not yet swept order is renewed', () async {
      await place(_transfer('t'));
      clock = due.add(const Duration(minutes: 2));
      final r = await renew('t');
      expect(r.statusCode, 200);
      expect((await json(r))['status'], 'awaiting_payment');
    });

    test(
      'live not due, staff-cancelled, cash, preparing, delivered -> 409',
      () async {
        await place(_transfer('live'));
        await place(_transfer('sc'));
        await send('PATCH', '/orders/sc', body: {'status': 'cancelled'});
        await place(_order('cash'));
        await place(_order('del'));
        await send('PATCH', '/orders/del', body: {'status': 'delivered'});
        for (final id in ['live', 'sc', 'cash', 'del']) {
          expect((await renew(id)).statusCode, 409, reason: id);
        }
        expect((await renew('nope')).statusCode, 404);
      },
    );

    test('transfer disabled -> 503 (after the state check)', () async {
      await expire('t');
      await api.close();
      db.close();
      // Same data is needed: rebuild with disabled settings.
      open(env: {});
      db.execute(
        "INSERT INTO orders (id, customer_name, status, placed_at, items_json, "
        "payment_method, payment_due_at) VALUES ('t', 'A', 'cancelled', "
        "'2026-11-19T12:00:00.000', '[]', 'bank_transfer', "
        "'2026-11-19T07:59:00.000Z')",
      );
      expect((await renew('t')).statusCode, 503);
      await place(_order('cash'));
      expect((await renew('cash')).statusCode, 409);
    });
  });

  group('races', () {
    test('renew then staff switch -> cash preparing', () async {
      await expire('t');
      expect((await renew('t')).statusCode, 200);
      expect((await staffSwitch('t')).statusCode, 200);
      expect((await get('t'))['paymentMethod'], 'cash');
      await expectStays('t', 'preparing');
    });

    test('staff switch then renew -> 409', () async {
      await expire('t');
      expect((await staffSwitch('t')).statusCode, 200);
      expect((await renew('t')).statusCode, 409);
    });

    test('renew then sweep at the old deadline leaves it live', () async {
      await expire('t');
      await renew('t');
      expect(api.expireOverdue(), 0);
      await expectStays('t', 'awaiting_payment');
    });

    test(
      'confirm on an expired order is 409 even after a renew-less sweep',
      () async {
        await expire('t');
        expect((await confirm('t')).statusCode, 409);
        await expectStays('t', 'cancelled');
      },
    );
  });

  group('staff routes', () {
    for (final route in ['staff-switch-to-cash', 'confirm-payment']) {
      test('$route: gate fails closed and checks before lookup', () async {
        await place(_transfer('t'));
        expect((await send('POST', '/orders/t/$route')).statusCode, 401);
        expect(
          (await send(
            'POST',
            '/orders/nope/$route',
            headers: {
              'x-staff-id': _staffId,
              'x-staff-password': 'wrong-password-123456',
            },
          )).statusCode,
          401,
        );
        await expectStays('t', 'awaiting_payment');
        // Wrong attempts so far: 2; three more lock out.
        for (var i = 0; i < 3; i++) {
          await send('POST', '/orders/t/$route');
        }
        final locked = await send('POST', '/orders/t/$route', headers: _staff);
        expect(locked.statusCode, 429);
        expect(locked.headers['retry-after'], isNotNull);
      });

      test('$route: disabled gate -> 403, even for unknown ids', () async {
        await api.close();
        db.close();
        open(gate: StaffGate());
        expect(
          (await send(
            'POST',
            '/orders/nope/$route',
            headers: _staff,
          )).statusCode,
          403,
        );
      });
    }

    test('staff switch: live and expired (hours later) -> 200', () async {
      await place(_transfer('live'));
      expect((await staffSwitch('live')).statusCode, 200);
      await expire('old');
      clock = due.add(const Duration(hours: 5));
      final r = await staffSwitch('old');
      expect(r.statusCode, 200);
      final o = await json(r);
      expect(o['paymentMethod'], 'cash');
      expect(o['status'], 'preparing');
      expect(o['paymentDueAt'], isNull);
    });

    test('staff switch: 409 for the other states, 404 unknown', () async {
      await place(_transfer('sc'));
      await send('PATCH', '/orders/sc', body: {'status': 'cancelled'});
      await place(_order('cash'));
      await place(_order('cc'));
      await send('PATCH', '/orders/cc', body: {'status': 'cancelled'});
      await place(_transfer('paid'));
      await confirm('paid');
      await send('PATCH', '/orders/paid', body: {'status': 'ready'});
      for (final id in ['sc', 'cash', 'cc', 'paid']) {
        expect((await staffSwitch(id)).statusCode, 409, reason: id);
      }
      expect((await staffSwitch('nope')).statusCode, 404);
    });

    test('confirm: live and renewed -> 200, method stays', () async {
      await place(_transfer('live'));
      final r = await confirm('live');
      expect(r.statusCode, 200);
      final o = await json(r);
      expect(o['status'], 'preparing');
      expect(o['paymentMethod'], 'bank_transfer');
      expect(o['paymentDueAt'], isNull);
      expect((await confirm('live')).statusCode, 409);

      await expire('re');
      await renew('re');
      expect((await confirm('re')).statusCode, 200);
    });

    test('confirm: overdue unswept, cash, unknown', () async {
      await place(_transfer('late'));
      clock = due;
      expect((await confirm('late')).statusCode, 409);
      await expectStays('late', 'cancelled');
      await place(_order('cash'));
      expect((await confirm('cash')).statusCode, 409);
      expect((await confirm('nope')).statusCode, 404);
    });
  });

  test('every transition publishes exactly one event', () async {
    final server = await io.serve(api.handler, InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.getUrl(
      Uri.parse('http://localhost:${server.port}/orders/stream'),
    );
    final response = await request.close();
    final events = <Map>[];
    var connected = false;
    final sub = response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) {
          if (l == ': connected') connected = true;
          if (l.startsWith('data: ')) {
            events.add(jsonDecode(l.substring(6)) as Map);
          }
        });
    addTearDown(sub.cancel);
    await waitFor(() => connected);

    await place(_transfer('t')); // 1: POST
    clock = due;
    api.expireOverdue(); // 2: cancelled
    await renew('t'); // 3: renewed
    await confirm('t'); // 4: confirmed
    await place(_transfer('u')); // 5
    await customerSwitch('u'); // 6
    await place(_transfer('v')); // 7
    await staffSwitch('v'); // 8
    await customerSwitch('v'); // 409: no event
    await waitFor(() => events.length >= 8);
    expect(events.map((e) => '${e['id']}:${e['status']}').toList(), [
      't:awaiting_payment',
      't:cancelled',
      't:awaiting_payment',
      't:preparing',
      'u:awaiting_payment',
      'u:preparing',
      'v:awaiting_payment',
      'v:preparing',
    ]);
  });

  test('odd ids give 404 and change nothing', () async {
    await place(_transfer('t'));
    final ids = [
      'a%2Fb',
      '%25',
      'x' * 64,
      Uri.encodeComponent("'; DROP TABLE orders;--"),
    ];
    for (final id in ids) {
      for (final r in [
        await customerSwitch(id),
        await renew(id),
        await staffSwitch(id),
        await confirm(id),
      ]) {
        expect(r.statusCode, 404, reason: id);
      }
    }
    expect(db.select('SELECT COUNT(*) AS n FROM orders').first['n'], 1);
    await expectStays('t', 'awaiting_payment');
  });
}
