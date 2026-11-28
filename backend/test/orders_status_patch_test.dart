import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/orders_report.dart';
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
  final due = DateTime.utc(2026, 11, 19, 8, 5);

  void open({StaffGate? gate}) {
    clock = DateTime.utc(2026, 11, 19, 8, 0);
    db = openDatabase(':memory:');
    api = OrdersApi(
      db,
      shopSettings: ShopSettings(_bankEnv),
      now: () => clock,
      staffGate:
          gate ??
          StaffGate(id: _staffId, password: _staffPassword, now: () => clock),
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

  Future<Response> patch(String id, String status) =>
      send('PATCH', '/orders/$id', body: {'status': status}, headers: _staff);

  Future<Map> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map;
  Future<List> list() async =>
      jsonDecode(await (await send('GET', '/orders')).readAsString()) as List;
  Map row(String id) =>
      db.select('SELECT * FROM orders WHERE id = ?', [id]).single;

  Future<void> place(Map<String, dynamic> order) async =>
      expect((await send('POST', '/orders', body: order)).statusCode, 200);

  /// An order cancelled by the expiry, as the sweep leaves it.
  Future<void> expire(String id) async {
    clock = DateTime.utc(2026, 11, 19, 8, 0);
    await place(_transfer(id));
    clock = due;
    expect(api.expireOverdue(), greaterThanOrEqualTo(1));
  }

  group('POST rejects the retired statuses', () {
    for (final status in ['ready', 'delivered']) {
      test('$status (cash, no method) -> 400, nothing stored', () async {
        final r = await send(
          'POST',
          '/orders',
          body: _order('x', extra: {'status': status}),
        );
        expect(r.statusCode, 400);
        expect(await list(), isEmpty);
      });
    }
  });

  group('PATCH staff check', () {
    setUp(() async => place(_order('c')));

    test('no headers -> 401 and nothing changes', () async {
      final r = await send('PATCH', '/orders/c', body: {'status': 'finished'});
      expect(r.statusCode, 401);
      expect(row('c')['status'], 'preparing');
    });

    test('wrong password -> 401', () async {
      final r = await send(
        'PATCH',
        '/orders/c',
        body: {'status': 'finished'},
        headers: {'x-staff-id': _staffId, 'x-staff-password': 'wrong-12345678'},
      );
      expect(r.statusCode, 401);
      expect(row('c')['status'], 'preparing');
    });

    test('staff routes disabled -> 403', () async {
      await api.close();
      db.close();
      open(gate: StaffGate());
      await place(_order('c'));
      final r = await send(
        'PATCH',
        '/orders/c',
        body: {'status': 'finished'},
        headers: _staff,
      );
      expect(r.statusCode, 403);
      expect(row('c')['status'], 'preparing');
    });

    test(
      'the check answers before a bad body, a bad status or a bad id',
      () async {
        for (final (label, path, body) in <(String, String, Object)>[
          ('invalid JSON', '/orders/c', '{not json'),
          ('empty body', '/orders/c', ''),
          ('unknown status', '/orders/c', {'status': 'shipped'}),
          ('retired status', '/orders/c', {'status': 'delivered'}),
          ('unknown id', '/orders/nope', {'status': 'finished'}),
        ]) {
          final r = await send('PATCH', path, body: body);
          expect(r.statusCode, 401, reason: label);
          expect(await r.readAsString(), isNot(contains('nope')));
        }
      },
    );

    test('with the check passed: bad body 400, unknown id 404', () async {
      Future<Response> p(String path, Object body) =>
          send('PATCH', path, body: body, headers: _staff);
      expect((await p('/orders/c', '{not json')).statusCode, 400);
      expect((await p('/orders/c', {'status': 'ready'})).statusCode, 400);
      expect((await p('/orders/c', {'status': 'delivered'})).statusCode, 400);
      expect((await p('/orders/nope', {'status': 'finished'})).statusCode, 404);
    });

    test(
      '5 wrong tries lock it: 429 with Retry-After, even when correct',
      () async {
        for (var i = 0; i < 5; i++) {
          final r = await send(
            'PATCH',
            '/orders/c',
            body: {'status': 'finished'},
            headers: {
              'x-staff-id': _staffId,
              'x-staff-password': 'wrong-12345678',
            },
          );
          expect(r.statusCode, 401);
        }
        final locked = await patch('c', 'finished');
        expect(locked.statusCode, 429);
        expect(locked.headers['retry-after'], isNotNull);
        expect(row('c')['status'], 'preparing');
      },
    );

    test('a correct call works', () async {
      final r = await patch('c', 'finished');
      expect(r.statusCode, 200);
      expect((await json(r))['status'], 'finished');
    });
  });

  group('PATCH moves', () {
    test('preparing <-> finished, method untouched', () async {
      await place(_order('c'));
      for (final s in ['finished', 'preparing', 'finished']) {
        final r = await patch('c', s);
        expect(r.statusCode, 200);
        final o = await json(r);
        expect(o['status'], s);
        expect(o['paymentMethod'], 'cash');
        expect(o['paymentDueAt'], isNull);
      }
    });

    test('same status is a 200 no-op', () async {
      await place(_order('c'));
      final before = row('c');
      final r = await patch('c', 'preparing');
      expect(r.statusCode, 200);
      expect(row('c'), before);
    });

    test(
      'every non-cancelled status can be cancelled, also finished',
      () async {
        await place(_order('prep'));
        await place(_order('fin'));
        await patch('fin', 'finished');
        await place(_transfer('aw'));
        for (final id in ['prep', 'fin', 'aw']) {
          final r = await patch(id, 'cancelled');
          expect(r.statusCode, 200, reason: id);
          final o = await json(r);
          expect(o['status'], 'cancelled');
          expect(o['paymentDueAt'], isNull, reason: id);
        }
        expect(row('aw')['payment_method'], 'bank_transfer');
      },
    );

    test(
      'an unpaid transfer order -> preparing, finished, cancelled',
      () async {
        for (final target in ['preparing', 'finished', 'cancelled']) {
          await place(_transfer(target));
          final r = await patch(target, target);
          expect(r.statusCode, 200, reason: target);
          final o = await json(r);
          expect(o['status'], target);
          expect(o['paymentMethod'], 'bank_transfer');
          expect(o['paymentDueAt'], isNull);
        }
      },
    );

    test('a no-op on an unpaid transfer order keeps its deadline', () async {
      await place(_transfer('t'));
      expect((await patch('t', 'awaiting_payment')).statusCode, 200);
      expect(row('t')['payment_due_at'], '2026-11-19T08:05:00.000Z');
    });

    test('a bank_transfer order can not go to awaiting_payment', () async {
      await place(_transfer('t'));
      await patch('t', 'preparing');
      final r = await patch('t', 'awaiting_payment');
      expect(r.statusCode, 409);
      expect(await r.readAsString(), 'Use the payment routes');
      expect(row('t')['status'], 'preparing');
    });

    test(
      'cash -> awaiting_payment stays cash with no deadline, then moves on',
      () async {
        for (final target in ['preparing', 'finished', 'cancelled']) {
          await place(_order(target));
          final r = await patch(target, 'awaiting_payment');
          expect(r.statusCode, 200);
          final o = await json(r);
          expect(o['status'], 'awaiting_payment');
          expect(o['paymentMethod'], 'cash');
          expect(o['paymentDueAt'], isNull);
          final back = await patch(target, target);
          expect(back.statusCode, 200, reason: target);
          expect((await json(back))['paymentMethod'], 'cash');
        }
      },
    );

    test('a legacy order with no method counts as cash', () async {
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
        "VALUES ('old', 'Bao', 'preparing', '2026-10-01T10:00:00.000', '[]')",
      );
      expect((await patch('old', 'awaiting_payment')).statusCode, 200);
      expect(row('old')['payment_method'], isNull, reason: 'never written');
    });
  });

  group('cancelled is final', () {
    test(
      'cash: 409 "A cancelled order can\'t be changed" for every target',
      () async {
        await place(_order('c'));
        await patch('c', 'cancelled');
        final before = row('c');
        for (final t in ['preparing', 'finished', 'awaiting_payment']) {
          final r = await patch('c', t);
          expect(r.statusCode, 409, reason: t);
          expect(await r.readAsString(), "A cancelled order can't be changed");
        }
        expect(row('c'), before);
      },
    );

    test('a legacy NULL-method cancelled order is treated as cash', () async {
      db.execute(
        'INSERT INTO orders (id, customer_name, status, placed_at, items_json) '
        "VALUES ('old', 'Bao', 'cancelled', '2026-10-01T10:00:00.000', '[]')",
      );
      final r = await patch('old', 'preparing');
      expect(r.statusCode, 409);
      expect(await r.readAsString(), "A cancelled order can't be changed");
    });

    test(
      'a staff-cancelled transfer order: 409 "Use the payment routes"',
      () async {
        await place(_transfer('t'));
        await patch('t', 'cancelled');
        final before = row('t');
        for (final t in ['preparing', 'finished', 'awaiting_payment']) {
          final r = await patch('t', t);
          expect(r.statusCode, 409, reason: t);
          expect(await r.readAsString(), 'Use the payment routes');
        }
        expect(row('t'), before);
      },
    );

    test(
      'an expiry-cancelled transfer order: 409 and the deadline stays',
      () async {
        await expire('t');
        for (final t in ['preparing', 'finished', 'awaiting_payment']) {
          final r = await patch('t', t);
          expect(r.statusCode, 409, reason: t);
          expect(await r.readAsString(), 'Use the payment routes');
        }
        expect(row('t')['status'], 'cancelled');
        expect(row('t')['payment_due_at'], '2026-11-19T08:05:00.000Z');
      },
    );

    test('cancelled -> cancelled with no deadline is a plain no-op', () async {
      await place(_order('c'));
      await patch('c', 'cancelled');
      final before = row('c');
      final r = await patch('c', 'cancelled');
      expect(r.statusCode, 200);
      expect(row('c'), before);
    });

    test(
      'a staff cancel of an expired order ends renew and switch-to-cash',
      () async {
        await expire('t');
        expect(row('t')['payment_due_at'], isNotNull);
        final r = await patch('t', 'cancelled');
        expect(r.statusCode, 200);
        final o = await json(r);
        expect(o['status'], 'cancelled');
        expect(o['paymentDueAt'], isNull);
        expect(o['paymentMethod'], 'bank_transfer');

        expect((await send('POST', '/orders/t/renew-payment')).statusCode, 409);
        expect(
          (await send('POST', '/orders/t/switch-to-cash')).statusCode,
          409,
        );
        expect(row('t')['status'], 'cancelled');
        expect(row('t')['payment_due_at'], isNull);
      },
    );
  });

  group('cash order in awaiting_payment (owner option A)', () {
    setUp(() async {
      await place(_order('cash'));
      expect((await patch('cash', 'awaiting_payment')).statusCode, 200);
    });

    test(
      'the sweep and a route call on another order leave it alone',
      () async {
        await place(_transfer('other'));
        clock = due.add(const Duration(hours: 2));
        expect(api.expireOverdue(), 1, reason: 'only the transfer order');
        await send('POST', '/orders/other/renew-payment');
        expect(row('cash')['status'], 'awaiting_payment');
        expect(row('cash')['payment_method'], 'cash');
        expect(row('cash')['payment_due_at'], isNull);
      },
    );

    test('all five payment routes answer 409', () async {
      for (final (method, path, headers)
          in <(String, String, Map<String, String>?)>[
            ('POST', '/orders/cash/confirm-payment', _staff),
            ('POST', '/orders/cash/switch-to-cash', null),
            ('POST', '/orders/cash/staff-switch-to-cash', _staff),
            ('POST', '/orders/cash/renew-payment', null),
            ('GET', '/orders/cash/payment-qr', null),
          ]) {
        final r = await send(method, path, headers: headers);
        expect(r.statusCode, 409, reason: path);
      }
      expect(row('cash')['status'], 'awaiting_payment');
      expect(row('cash')['payment_method'], 'cash');
    });

    test('it counts in no report', () async {
      final orders = (await list()).cast<Map<String, dynamic>>();
      expect(finishedOrders(orders, '2026-11'), isEmpty);
    });
  });

  group('sweep and routes (SF17)', () {
    test('an overdue order staff moved to preparing is not touched', () async {
      await place(_transfer('t'));
      await patch('t', 'preparing');
      await place(_transfer('other'));
      clock = due.add(const Duration(hours: 1));
      expect(api.expireOverdue(), 1, reason: 'only the other order');
      await send('POST', '/orders/other/switch-to-cash');
      expect(row('t')['status'], 'preparing');
      for (final (method, path, headers)
          in <(String, String, Map<String, String>?)>[
            ('POST', '/orders/t/confirm-payment', _staff),
            ('POST', '/orders/t/switch-to-cash', null),
            ('POST', '/orders/t/staff-switch-to-cash', _staff),
            ('POST', '/orders/t/renew-payment', null),
            ('GET', '/orders/t/payment-qr', null),
          ]) {
        expect((await send(method, path, headers: headers)).statusCode, 409);
      }
      expect(row('t')['status'], 'preparing');
    });

    test(
      'an order cancelled by the expiry can still be renewed or switched',
      () async {
        await expire('r');
        await expire('s');
        final renewed = await send('POST', '/orders/r/renew-payment');
        expect(renewed.statusCode, 200);
        expect((await json(renewed))['status'], 'awaiting_payment');
        final switched = await send('POST', '/orders/s/switch-to-cash');
        expect(switched.statusCode, 200);
        expect((await json(switched))['status'], 'preparing');
      },
    );
  });

  group('reports follow the status', () {
    test('an order moved into and out of finished changes the month', () async {
      await place(_order('c'));
      Future<int> counted() async => finishedOrders(
        (await list()).cast<Map<String, dynamic>>(),
        '2026-11',
      ).length;
      expect(await counted(), 0);
      await patch('c', 'finished');
      expect(await counted(), 1);
      final days = dailyTotals(
        finishedOrders((await list()).cast<Map<String, dynamic>>(), '2026-11'),
        '2026-11',
      );
      expect(days.fold<int>(0, (n, d) => n + d.orders.length), 1);
      await patch('c', 'preparing');
      expect(await counted(), 0);
    });

    test('preparing, awaiting_payment and cancelled count nowhere', () async {
      await place(_order('p'));
      await place(_transfer('a'));
      await place(_order('x'));
      await patch('x', 'cancelled');
      expect(
        finishedOrders((await list()).cast<Map<String, dynamic>>(), '2026-11'),
        isEmpty,
      );
    });
  });

  group('the stream carries each change', () {
    test('a status change and a staff cancel of an expired order', () async {
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
      final it = StreamIterator(frames.stream);
      expect(await it.moveNext(), isTrue);

      Future<Map> nextEvent() async {
        while (await it.moveNext().timeout(const Duration(seconds: 5))) {
          if (it.current.startsWith('data: ')) {
            return jsonDecode(it.current.substring(6)) as Map;
          }
        }
        fail('stream ended');
      }

      await place(_order('c'));
      expect((await nextEvent())['status'], 'preparing');
      await patch('c', 'finished');
      final e = await nextEvent();
      expect(e['id'], 'c');
      expect(e['status'], 'finished');

      await expire('t');
      expect((await nextEvent())['id'], 't'); // the POST
      expect((await nextEvent())['status'], 'cancelled'); // the sweep
      await patch('t', 'cancelled');
      final cleared = await nextEvent();
      expect(cleared['status'], 'cancelled');
      expect(cleared['paymentDueAt'], isNull);
      await it.cancel();
    });
  });
}
