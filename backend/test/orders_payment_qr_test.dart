import 'dart:convert';

import 'package:food_orders_backend/database.dart';
import 'package:food_orders_backend/orders_api.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:food_orders_backend/staff_gate.dart';
import 'package:food_orders_backend/vietqr.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'vietqr_test.dart' show asMap, readTlv;

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
const _id = '1763550482913';

// 2 x (25000 + 10000) + 4000 = 74000
Map<String, dynamic> _order(String id, {Map<String, dynamic>? extra}) => {
  'id': id,
  'customerName': 'Alice',
  'items': [
    {
      'name': 'Xoi thit',
      'quantity': 2,
      'price': 25000,
      'toppings': [
        {'name': 'Them cha', 'price': 10000},
      ],
    },
    {'name': 'Tra da', 'quantity': 1, 'price': 4000},
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

  void open({Map<String, String?> env = _bankEnv}) {
    clock = DateTime.utc(2026, 11, 19, 8, 0);
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
        headers: headers,
        body: body is String || body == null ? body : jsonEncode(body),
      ),
    ),
  );

  Future<Map> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map;
  Future<Response> qr(String id) => send('GET', '/orders/$id/payment-qr');

  Future<void> place(Map<String, dynamic> order) async {
    expect((await send('POST', '/orders', body: order)).statusCode, 200);
  }

  group('GET /payment-info', () {
    test('enabled: the account fields are there', () async {
      final r = await send('GET', '/payment-info');
      expect(r.statusCode, 200);
      expect(r.headers['cache-control'], 'no-store');
      expect(await json(r), {
        'transferEnabled': true,
        'bankName': 'Ngan hang Thu',
        'accountNumber': '1234567890',
        'accountName': 'LE VAN HUNG',
      });
    });

    test('disabled: only the flag, no account fields', () async {
      await api.close();
      db.close();
      open(env: {..._bankEnv, 'BANK_ACCOUNT': null});
      final r = await send('GET', '/payment-info');
      expect(r.statusCode, 200);
      expect(await json(r), {'transferEnabled': false});
    });

    test('works with no settings at all', () async {
      await api.close();
      db.close();
      open(env: {});
      expect(await json(await send('GET', '/payment-info')), {
        'transferEnabled': false,
      });
    });
  });

  group('GET /orders/{id}/payment-qr', () {
    test(
      '200 for a live transfer order, amount from the stored items',
      () async {
        await place(_transfer(_id));
        final r = await qr(_id);
        expect(r.statusCode, 200);
        expect(r.headers['cache-control'], 'no-store');
        expect(r.headers['content-type'], contains('application/json'));
        final body = await json(r);
        expect(body.keys.toSet(), {
          'payload',
          'amount',
          'reference',
          'dueAt',
          'bankName',
          'accountNumber',
          'accountName',
        });
        expect(body['amount'], 74000);
        expect(body['reference'], 'DH482913');
        expect(body['dueAt'], '2026-11-19T08:05:00.000Z');
        expect(body['bankName'], 'Ngan hang Thu');
        expect(body['accountNumber'], '1234567890');
        expect(body['accountName'], 'LE VAN HUNG');
        expect(
          body['payload'],
          vietQrPayload(
            bin: '000000',
            account: '1234567890',
            amount: 74000,
            reference: 'DH482913',
          ),
        );
        final fields = asMap(readTlv(body['payload'] as String));
        expect(fields['54'], '74000');
      },
    );

    test('the request cannot change the amount or reference', () async {
      await place(_transfer(_id));
      final plain = await json(await qr(_id));
      final r = await send(
        'GET',
        '/orders/$_id/payment-qr?amount=1&reference=EVIL&price=1',
        headers: {'x-amount': '1'},
      );
      expect(await json(r), plain);
    });

    test('404 for an unknown id', () async {
      final r = await qr('999');
      expect(r.statusCode, 404);
      expect(await r.readAsString(), 'Order not found');
    });

    test('503 when bank transfer is not set up', () async {
      await place(_transfer(_id));
      await api.close();
      final stored = db.select('SELECT * FROM orders').length;
      expect(stored, 1);
      // A new API on the same database, without bank details.
      api = OrdersApi(db, shopSettings: ShopSettings({}), now: () => clock);
      final r = await qr(_id);
      expect(r.statusCode, 503);
      expect(await r.readAsString(), 'Bank transfer is not set up');
    });

    test('409 for a cash order', () async {
      await place(_order('111111'));
      expect((await qr('111111')).statusCode, 409);
    });

    test('409 once confirmed (paid)', () async {
      await place(_transfer(_id));
      expect(
        (await send(
          'POST',
          '/orders/$_id/confirm-payment',
          headers: _staff,
        )).statusCode,
        200,
      );
      expect((await qr(_id)).statusCode, 409);
    });

    test('409 after the customer switched to cash', () async {
      await place(_transfer(_id));
      expect(
        (await send('POST', '/orders/$_id/switch-to-cash')).statusCode,
        200,
      );
      expect((await qr(_id)).statusCode, 409);
    });

    test('409 after staff cancelled it', () async {
      await place(_transfer(_id));
      await send('PATCH', '/orders/$_id', body: {'status': 'cancelled'});
      expect((await qr(_id)).statusCode, 409);
    });

    test('409 for an expired (cancelled) order, swept', () async {
      await place(_transfer(_id));
      clock = DateTime.utc(2026, 11, 19, 8, 5);
      expect(api.expireOverdue(), 1);
      expect((await qr(_id)).statusCode, 409);
    });

    test('409 for an overdue order the sweep has not reached', () async {
      await place(_transfer(_id));
      clock = DateTime.utc(2026, 11, 19, 8, 5);
      final r = await qr(_id);
      expect(r.statusCode, 409);
      // The lazy check cancelled it, like the other payment routes.
      expect(
        db.select('SELECT status FROM orders').single['status'],
        'cancelled',
      );
    });

    test('still served one millisecond before the deadline', () async {
      await place(_transfer(_id));
      clock = DateTime.utc(2026, 11, 19, 8, 4, 59, 999);
      expect((await qr(_id)).statusCode, 200);
    });

    test(
      'a renewed order: same amount, reference, payload; new dueAt',
      () async {
        await place(_transfer(_id));
        final before = await json(await qr(_id));
        clock = DateTime.utc(2026, 11, 19, 8, 5);
        expect(api.expireOverdue(), 1);
        expect((await qr(_id)).statusCode, 409); // still cancelled

        clock = DateTime.utc(2026, 11, 19, 8, 10);
        expect(
          (await send('POST', '/orders/$_id/renew-payment')).statusCode,
          200,
        );
        final after = await json(await qr(_id));
        expect(after['amount'], before['amount']);
        expect(after['reference'], before['reference']);
        expect(after['payload'], before['payload']);
        expect(after['dueAt'], '2026-11-19T08:15:00.000Z');
        expect(after['dueAt'], isNot(before['dueAt']));
      },
    );

    test('409 when the stored total is not whole VND', () async {
      final o = _transfer(_id);
      o['items'] = [
        {'name': 'Odd', 'quantity': 1, 'price': 100.5},
      ];
      await place(o);
      expect((await qr(_id)).statusCode, 409);
    });

    test(
      'a malformed stored order gives a fixed 500, no data echoed',
      () async {
        await place(_transfer(_id));
        db.execute('UPDATE orders SET items_json = ? WHERE id = ?', [
          '[{"name":"x","quantity":1,"price":"zzz-secret"}]',
          _id,
        ]);
        final r = await qr(_id);
        expect(r.statusCode, 500);
        final text = await r.readAsString();
        expect(text, 'The payment QR could not be made');
        expect(text, isNot(contains('secret')));
      },
    );

    test('a stored item that is not a map gives the fixed 500', () async {
      await place(_transfer(_id));
      db.execute('UPDATE orders SET items_json = ? WHERE id = ?', [
        '["not-a-map-secret"]',
        _id,
      ]);
      final r = await qr(_id);
      expect(r.statusCode, 500);
      final text = await r.readAsString();
      expect(text, 'The payment QR could not be made');
      expect(text, isNot(contains('secret')));
    });

    test('errors never echo the id', () async {
      final r = await qr('probe-<script>');
      expect(await r.readAsString(), isNot(contains('script')));
    });
  });
}
