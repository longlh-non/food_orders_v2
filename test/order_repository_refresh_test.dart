import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/api/order_repository.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Order order(String id, OrderStatus status) => Order(
  id: id,
  customerName: 'An',
  items: [OrderItem(name: 'Xôi thịt', quantity: 1, price: 25000)],
  status: status,
  placedAt: DateTime(2026, 11, 19, 10),
);

void useServer(http.Response Function(http.Request) handler) => OrderRepository
    .instance
    .setApiForTest(OrderApiClient(client: MockClient((r) async => handler(r))));

void main() {
  final repo = OrderRepository.instance;
  setUp(() => repo.setOrdersForTest(const []));
  tearDown(() {
    repo
      ..setApiForTest(OrderApiClient())
      ..setOrdersForTest(const []);
  });

  test('refresh merges the server list: replaces and adds', () async {
    repo.setOrdersForTest([order('a', OrderStatus.preparing)]);
    useServer(
      (_) => http.Response.bytes(
        utf8.encode(
          jsonEncode([
            order('a', OrderStatus.ready).toJson(),
            order('b', OrderStatus.preparing).toJson(),
          ]),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    var notified = 0;
    repo.addListener(() => notified++);

    await repo.refresh();

    expect(repo.orders.map((o) => o.id).toSet(), {'a', 'b'});
    expect(
      repo.orders.firstWhere((o) => o.id == 'a').status,
      OrderStatus.ready,
    );
    expect(notified, 1);
  });

  test('refresh keeps unseen orders newest-first, like the server', () async {
    repo.setOrdersForTest([order('old', OrderStatus.preparing)]);
    useServer(
      (_) => http.Response.bytes(
        utf8.encode(
          jsonEncode([
            order('new2', OrderStatus.preparing).toJson(),
            order('new1', OrderStatus.preparing).toJson(),
            order('old', OrderStatus.preparing).toJson(),
          ]),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    await repo.refresh();

    expect(repo.orders.map((o) => o.id), ['new2', 'new1', 'old']);
  });

  test('refresh swallows errors and keeps the cache', () async {
    repo.setOrdersForTest([order('a', OrderStatus.preparing)]);
    for (final handler in <http.Response Function(http.Request)>[
      (_) => http.Response('<html>', 500),
      (_) => http.Response('{"not":"a list"}', 200),
      (_) => throw http.ClientException('down'),
    ]) {
      useServer(handler);
      await repo.refresh();
      expect(repo.orders.single.status, OrderStatus.preparing);
    }
  });
}
