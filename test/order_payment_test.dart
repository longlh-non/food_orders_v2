import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> baseJson({Object? status = 'preparing'}) => {
  'id': 'abc',
  'customerName': 'An',
  'items': [
    {'name': 'Xôi thịt', 'quantity': 1, 'price': 25000},
  ],
  'status': status,
  'placedAt': '2026-11-19T12:00:00.000',
};

Order build({
  OrderStatus status = OrderStatus.preparing,
  PaymentMethod method = PaymentMethod.cash,
  DateTime? due,
  String id = 'abc',
}) => Order(
  id: id,
  customerName: 'An',
  items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
  status: status,
  placedAt: DateTime(2026, 11, 19, 12),
  paymentMethod: method,
  paymentDueAt: due,
);

http.Response reply(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> expectFailure(Future<Object?> call, int? statusCode) =>
    expectLater(
      call,
      throwsA(
        isA<OrderRequestException>().having(
          (e) => e.statusCode,
          'statusCode',
          statusCode,
        ),
      ),
    );

void main() {
  final due = DateTime.utc(2026, 11, 19, 12, 5);

  group('Order payment fields', () {
    test('old JSON without the new keys is cash with no deadline', () {
      final o = Order.fromJson(baseJson());
      expect(o.paymentMethod, PaymentMethod.cash);
      expect(o.paymentDueAt, isNull);
    });

    test('bank_transfer with a UTC deadline parses', () {
      final o = Order.fromJson({
        ...baseJson(status: 'awaiting_payment'),
        'paymentMethod': 'bank_transfer',
        'paymentDueAt': '2026-11-19T12:05:00.000Z',
      });
      expect(o.status, OrderStatus.awaiting_payment);
      expect(o.paymentMethod, PaymentMethod.bank_transfer);
      expect(o.paymentDueAt, due);
      expect(o.paymentDueAt!.isUtc, isTrue);
    });

    test('null paymentDueAt is null', () {
      final o = Order.fromJson({...baseJson(), 'paymentDueAt': null});
      expect(o.paymentDueAt, isNull);
    });

    for (final bad in <Object?>['card', 1, null, true, '']) {
      test('a bad paymentMethod ($bad) throws FormatException', () {
        expect(
          () => Order.fromJson({...baseJson(), 'paymentMethod': bad}),
          throwsFormatException,
        );
      });
    }

    test('a non-string paymentDueAt throws FormatException', () {
      expect(
        () => Order.fromJson({...baseJson(), 'paymentDueAt': 5}),
        throwsFormatException,
      );
    });

    test('pending and accepted no longer parse', () {
      for (final old in ['pending', 'accepted']) {
        expect(
          () => Order.fromJson(baseJson(status: old)),
          throwsArgumentError,
        );
      }
    });

    test('toJson has paymentMethod and never paymentDueAt', () {
      final json = build(
        status: OrderStatus.awaiting_payment,
        method: PaymentMethod.bank_transfer,
        due: due,
      ).toJson();
      expect(json['paymentMethod'], 'bank_transfer');
      expect(json['status'], 'awaiting_payment');
      expect(json.containsKey('paymentDueAt'), isFalse);
      expect(build().toJson()['paymentMethod'], 'cash');
    });

    test(
      'round trip keeps the method; the deadline comes only from the server',
      () {
        final o = build(method: PaymentMethod.bank_transfer, due: due);
        final back = Order.fromJson(
          jsonDecode(
            jsonEncode({...o.toJson(), 'paymentDueAt': due.toIso8601String()}),
          ) as Map<String, dynamic>,
        );
        expect(back.paymentMethod, PaymentMethod.bank_transfer);
        expect(back.paymentDueAt, due);
        expect(back.status, o.status);
      },
    );

    test('copyWith carries the new fields', () {
      final o = build().copyWith(
        status: OrderStatus.awaiting_payment,
        paymentMethod: PaymentMethod.bank_transfer,
        paymentDueAt: due,
      );
      expect(o.paymentMethod, PaymentMethod.bank_transfer);
      expect(o.paymentDueAt, due);
      expect(o.status, OrderStatus.awaiting_payment);
      expect(o.copyWith().paymentDueAt, due);
    });
  });

  group('expiredUnpaid and renewableUntil', () {
    test('true only for cancelled + bank_transfer + a deadline', () {
      for (final status in OrderStatus.values) {
        for (final method in PaymentMethod.values) {
          for (final d in <DateTime?>[null, due]) {
            final o = build(status: status, method: method, due: d);
            final expected =
                status == OrderStatus.cancelled &&
                method == PaymentMethod.bank_transfer &&
                d != null;
            expect(o.expiredUnpaid, expected, reason: '$status $method $d');
            expect(
              o.renewableUntil,
              expected ? due.add(const Duration(minutes: 15)) : isNull,
            );
          }
        }
      }
    });
  });

  group('labels', () {
    test('every status and method has a non-empty label', () {
      for (final s in OrderStatus.values) {
        expect(s.label, isNotEmpty);
      }
      expect(PaymentMethod.cash.label, 'Tiền mặt');
      expect(PaymentMethod.bank_transfer.label, 'Chuyển khoản');
    });

    test('every status label is Vietnamese now, not the old English text', () {
      // The labels this card replaced (lib/shared/models/order.dart,
      // `vi-translate-shared-and-restaurant-ui`). Kept here so a future
      // revert is caught by a test, not just by eye.
      const oldEnglish = {
        OrderStatus.awaiting_payment: 'Awaiting payment',
        OrderStatus.preparing: 'Preparing',
        OrderStatus.ready: 'Ready for pickup',
        OrderStatus.delivered: 'Delivered',
        OrderStatus.cancelled: 'Cancelled',
      };
      for (final s in OrderStatus.values) {
        expect(s.label, isNotEmpty);
        expect(s.label, isNot(oldEnglish[s]), reason: '$s still in English');
      }
    });
  });

  group('payment calls', () {
    const staff = {
      'X-Staff-Id': 'boss-id',
      'X-Staff-Password': 'hunter2-secret',
    };

    OrderApiClient answering(
      http.Response Function(http.Request) respond, [
      List<http.Request>? log,
    ]) => OrderApiClient(
      client: MockClient((r) async {
        log?.add(r);
        return respond(r);
      }),
    );

    test('placeOrder sends paymentMethod and never paymentDueAt', () async {
      final sent = <http.Request>[];
      final api = answering((_) => reply(baseJson()), sent);
      await api.placeOrder(
        build(method: PaymentMethod.bank_transfer, due: due),
      );
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(body['paymentMethod'], 'bank_transfer');
      expect(body.containsKey('paymentDueAt'), isFalse);
    });

    test(
      'switchToCash and renewPayment: path, method, no body, parsed reply',
      () async {
        final sent = <http.Request>[];
        final api = answering(
          (_) => reply({...baseJson(), 'paymentMethod': 'cash'}),
          sent,
        );
        final a = await api.switchToCash('abc');
        final b = await api.renewPayment('abc');
        expect(sent.map((r) => '${r.method} ${r.url.path}'), [
          'POST /api/orders/abc/switch-to-cash',
          'POST /api/orders/abc/renew-payment',
        ]);
        expect(sent.every((r) => r.body.isEmpty), isTrue);
        expect(a.status, OrderStatus.preparing);
        expect(b.id, 'abc');
      },
    );

    test('409 and 503 become OrderRequestException with the status', () async {
      await expectFailure(
        answering((_) => http.Response('nope', 409)).switchToCash('abc'),
        409,
      );
      await expectFailure(
        answering((_) => http.Response('nope', 409)).renewPayment('abc'),
        409,
      );
      await expectFailure(
        answering((_) => http.Response('nope', 503)).renewPayment('abc'),
        503,
      );
    });

    test('no answer throws with no status', () async {
      final api = OrderApiClient(
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      await expectFailure(api.switchToCash('abc'), null);
    });

    test('staff calls send exactly the given headers to their paths', () async {
      final sent = <http.Request>[];
      final api = answering((_) => reply(baseJson()), sent);
      await api.staffSwitchToCash('abc', staffHeaders: staff);
      await api.confirmPayment('abc', staffHeaders: staff);
      expect(sent.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/orders/abc/staff-switch-to-cash',
        'POST /api/orders/abc/confirm-payment',
      ]);
      for (final r in sent) {
        expect(r.headers['X-Staff-Id'], 'boss-id');
        expect(r.headers['X-Staff-Password'], 'hunter2-secret');
        expect(r.url.hasQuery, isFalse);
      }
    });

    test('customer calls send no staff headers', () async {
      final sent = <http.Request>[];
      await answering((_) => reply(baseJson()), sent).switchToCash('abc');
      expect(
        sent.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-staff-id')),
      );
    });

    test('ids with / ? % are encoded in every call', () async {
      final sent = <http.Request>[];
      final api = answering((_) => reply(baseJson()), sent);
      const id = '../menu?x=1%zz';
      await api.switchToCash(id);
      await api.renewPayment(id);
      await api.staffSwitchToCash(id, staffHeaders: staff);
      await api.confirmPayment(id, staffHeaders: staff);
      for (final r in sent) {
        expect(r.url.pathSegments.length, 4);
        expect(r.url.pathSegments[2], id);
        expect(r.url.hasQuery, isFalse);
        expect(r.url.toString(), contains('..%2Fmenu%3Fx%3D1%25zz'));
      }
    });

    test('a reply with an unknown status is the invalid-order error', () async {
      final api = answering((_) => reply(baseJson(status: 'accepted')));
      await expectLater(
        api.switchToCash('abc'),
        throwsA(
          isA<OrderRequestException>().having(
            (e) => e.message,
            'message',
            contains('invalid order'),
          ),
        ),
      );
    });

    test('staff header values never appear in an exception', () async {
      for (final response in [
        http.Response('hunter2-secret boss-id', 401),
        http.Response('{"status":"pending"}', 200),
        reply(baseJson(status: 'pending')),
      ]) {
        final api = answering((_) => response);
        for (final call in [
          () => api.confirmPayment('abc', staffHeaders: staff),
          () => api.staffSwitchToCash('abc', staffHeaders: staff),
        ]) {
          try {
            await call();
            fail('should throw');
          } on OrderRequestException catch (e) {
            final text = '${e.message} $e';
            expect(text, isNot(contains('hunter2-secret')));
            expect(text, isNot(contains('boss-id')));
          }
        }
      }
    });
  });

  group('OrderRepository payment merges', () {
    final repo = OrderRepository.instance;
    void reset() {
      repo.setApiForTest(OrderApiClient());
      repo.setOrdersForTest(const []);
    }

    setUp(reset);
    tearDown(reset);

    const staff = {'X-Staff-Id': 'a', 'X-Staff-Password': 'b'};
    final expired = build(
      status: OrderStatus.cancelled,
      method: PaymentMethod.bank_transfer,
      due: due,
    );

    Future<void> Function() callFor(String name) => switch (name) {
      'switchToCash' => () => repo.switchToCash('abc'),
      'renewPayment' => () => repo.renewPayment('abc'),
      'staffSwitchToCash' => () => repo.staffSwitchToCash(
        'abc',
        staffHeaders: staff,
      ),
      _ => () => repo.confirmPayment('abc', staffHeaders: staff),
    };

    for (final name in [
      'switchToCash',
      'renewPayment',
      'staffSwitchToCash',
      'confirmPayment',
    ]) {
      test('$name: failure leaves the cache and does not notify', () async {
        repo.setOrdersForTest([expired]);
        repo.setApiForTest(
          OrderApiClient(
            client: MockClient((_) async => http.Response('no', 409)),
          ),
        );
        var notified = 0;
        void listener() => notified++;
        repo.addListener(listener);
        addTearDown(() => repo.removeListener(listener));

        await expectFailure(callFor(name)(), 409);

        expect(repo.orders.single.status, OrderStatus.cancelled);
        expect(repo.orders.single.paymentDueAt, due);
        expect(notified, 0);
      });
    }

    test('cancelled -> preparing (cash) merges and notifies', () async {
      repo.setOrdersForTest([expired]);
      repo.setApiForTest(
        OrderApiClient(
          client: MockClient(
            (_) async => reply({...baseJson(), 'paymentMethod': 'cash'}),
          ),
        ),
      );
      var notified = 0;
      void listener() => notified++;
      repo.addListener(listener);
      addTearDown(() => repo.removeListener(listener));

      await repo.switchToCash('abc');

      expect(repo.orders.single.status, OrderStatus.preparing);
      expect(repo.orders.single.paymentMethod, PaymentMethod.cash);
      expect(repo.orders.single.paymentDueAt, isNull);
      expect(notified, 1);
    });

    test('cancelled -> awaiting_payment (renewed) merges', () async {
      repo.setOrdersForTest([expired]);
      repo.setApiForTest(
        OrderApiClient(
          client: MockClient(
            (_) async => reply({
              ...baseJson(status: 'awaiting_payment'),
              'paymentMethod': 'bank_transfer',
              'paymentDueAt': '2026-11-19T12:20:00.000Z',
            }),
          ),
        ),
      );

      await repo.renewPayment('abc');

      final o = repo.orders.single;
      expect(o.status, OrderStatus.awaiting_payment);
      expect(o.paymentDueAt, DateTime.utc(2026, 11, 19, 12, 20));
      expect(o.expiredUnpaid, isFalse);
    });

    test('staff calls merge the reply', () async {
      repo.setOrdersForTest([
        build(
          status: OrderStatus.awaiting_payment,
          method: PaymentMethod.bank_transfer,
          due: due,
        ),
      ]);
      repo.setApiForTest(
        OrderApiClient(
          client: MockClient(
            (_) async => reply({
              ...baseJson(),
              'paymentMethod': 'bank_transfer',
              'paymentDueAt': null,
            }),
          ),
        ),
      );

      await repo.confirmPayment('abc', staffHeaders: staff);

      expect(repo.orders.single.status, OrderStatus.preparing);
      expect(repo.orders.single.paymentMethod, PaymentMethod.bank_transfer);
      expect(repo.orders.single.paymentDueAt, isNull);
    });
  });
}
