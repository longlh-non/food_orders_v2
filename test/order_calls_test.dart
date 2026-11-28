import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final order = Order(
  id: '1731400000000',
  customerName: 'An',
  items: [
    OrderItem(
      menuItemId: 'xoi-thit',
      name: 'Xôi thịt',
      quantity: 1,
      price: 25000,
      toppings: const [OrderTopping(id: 'cha', name: 'Thêm chả', price: 10000)],
    ),
  ],
  status: OrderStatus.preparing,
  placedAt: DateTime(2026, 11, 13, 8, 30),
);

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

OrderApiClient clientAnswering(Future<http.Response> Function() respond) =>
    OrderApiClient(client: MockClient((_) => respond()));

/// Expects [call] to throw an [OrderRequestException] with [statusCode].
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

/// Fake staff headers; the tests only check they are sent.
const staff = {'X-Staff-Id': 'boss-id', 'X-Staff-Password': 'hunter2-secret'};

void main() {
  group('placeOrder', () {
    test('200 with a valid order returns it', () async {
      final api = clientAnswering(() async => json(order.toJson()));
      final placed = await api.placeOrder(order);
      expect(placed.id, order.id);
      expect(placed.items.single.toppings.single.name, 'Thêm chả');
    });

    test('sends POST /api/orders with the order as JSON', () async {
      late http.Request sent;
      final api = OrderApiClient(
        client: MockClient((request) async {
          sent = request;
          return json(order.toJson());
        }),
      );
      await api.placeOrder(order);
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/orders');
      expect(jsonDecode(sent.body), order.toJson());
    });

    for (final (status, body) in [
      (400, 'items[0] has unknown fields'),
      (409, 'Order already exists'),
      (500, 'Internal Server Error'),
    ]) {
      test('$status with a plain-text body throws, status $status', () async {
        final api = clientAnswering(() async => http.Response(body, status));
        await expectFailure(api.placeOrder(order), status);
      });
    }

    test('no answer (ClientException) throws with no status', () async {
      final api = clientAnswering(
        () async => throw http.ClientException('Connection refused'),
      );
      await expectFailure(api.placeOrder(order), null);
    });

    test('200 with a body that is not JSON throws, status 200', () async {
      final api = clientAnswering(() async => http.Response('<html>', 200));
      await expectFailure(api.placeOrder(order), 200);
    });

    test('200 with JSON that is not an order throws, status 200', () async {
      final api = clientAnswering(() async => json({'id': 42}));
      await expectFailure(api.placeOrder(order), 200);
      final list = clientAnswering(() async => json([1, 2]));
      await expectFailure(list.placeOrder(order), 200);
    });

    test(
      '200 with a status this app does not know throws, status 200',
      () async {
        final api = clientAnswering(
          () async => json({...order.toJson(), 'status': 'bogus'}),
        );
        await expectFailure(api.placeOrder(order), 200);
      },
    );

    test('the message never contains the server body', () async {
      final api = clientAnswering(
        () async => http.Response('secret server detail', 400),
      );
      try {
        await api.placeOrder(order);
        fail('should throw');
      } on OrderRequestException catch (e) {
        expect(e.message, isNot(contains('secret server detail')));
        expect(e.toString(), isNot(contains('secret server detail')));
      }
    });
  });

  group('updateStatus', () {
    test('200 returns the updated order', () async {
      late http.Request sent;
      final api = OrderApiClient(
        client: MockClient((request) async {
          sent = request;
          return json(order.copyWith(status: OrderStatus.ready).toJson());
        }),
      );
      final updated = await api.updateStatus(
        order.id,
        OrderStatus.ready,
        staffHeaders: staff,
      );
      expect(updated.status, OrderStatus.ready);
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/api/orders/${order.id}');
      expect(jsonDecode(sent.body), {'status': 'ready'});
    });

    test('the id is encoded, so it cannot change the path or query', () async {
      late http.Request sent;
      final api = OrderApiClient(
        client: MockClient((request) async {
          sent = request;
          return json(order.toJson());
        }),
      );
      await api.updateStatus(
        '../menu?x=1%zz',
        OrderStatus.ready,
        staffHeaders: staff,
      );
      expect(sent.url.pathSegments, ['api', 'orders', '../menu?x=1%zz']);
      expect(sent.url.hasQuery, isFalse);
      expect(sent.url.toString(), '/api/orders/..%2Fmenu%3Fx%3D1%25zz');
    });

    test('404 throws, status 404', () async {
      final api = clientAnswering(
        () async => http.Response('Order not found', 404),
      );
      await expectFailure(
        api.updateStatus('nope', OrderStatus.ready, staffHeaders: staff),
        404,
      );
    });

    test('no answer throws with no status', () async {
      final api = clientAnswering(
        () async => throw http.ClientException('Connection refused'),
      );
      await expectFailure(
        api.updateStatus(order.id, OrderStatus.ready, staffHeaders: staff),
        null,
      );
    });
  });

  group('OrderRepository', () {
    final repo = OrderRepository.instance;

    void reset() {
      repo.setApiForTest(OrderApiClient());
      repo.setOrdersForTest(const []);
    }

    setUp(reset);
    tearDown(reset);

    test('a failed placeOrder throws and leaves the cache unchanged', () async {
      repo.setApiForTest(
        clientAnswering(() async => http.Response('bad', 400)),
      );
      var notified = 0;
      void listener() => notified++;
      repo.addListener(listener);
      addTearDown(() => repo.removeListener(listener));

      await expectFailure(repo.placeOrder(order), 400);

      expect(repo.orders, isEmpty);
      expect(notified, 0);
    });

    test('a successful placeOrder merges the server copy', () async {
      repo.setApiForTest(clientAnswering(() async => json(order.toJson())));
      var notified = 0;
      void listener() => notified++;
      repo.addListener(listener);
      addTearDown(() => repo.removeListener(listener));

      await repo.placeOrder(order);

      expect(repo.orders.map((o) => o.id), [order.id]);
      expect(notified, 1);
    });

    test('a failed updateStatus throws and keeps the old status', () async {
      repo.setOrdersForTest([order]);
      repo.setApiForTest(
        clientAnswering(
          () async => http.Response('Internal Server Error', 500),
        ),
      );

      await expectFailure(
        repo.updateStatus(order.id, OrderStatus.ready, staffHeaders: staff),
        500,
      );

      expect(repo.orders.single.status, OrderStatus.preparing);
    });

    test('a successful updateStatus replaces the cached order', () async {
      repo.setOrdersForTest([order]);
      repo.setApiForTest(
        clientAnswering(
          () async => json(order.copyWith(status: OrderStatus.ready).toJson()),
        ),
      );

      await repo.updateStatus(order.id, OrderStatus.ready, staffHeaders: staff);

      expect(repo.orders.single.status, OrderStatus.ready);
    });
  });
}
