import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_orders/shared/api/order_api_client.dart';
import 'package:food_orders/shared/models/order.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> orderJson(String id, {Object? quantity = 1}) => {
  'id': id,
  'customerName': 'Bao',
  'items': [
    {'name': 'Xôi thịt', 'quantity': quantity, 'price': 25000},
  ],
  'status': 'preparing',
  'placedAt': '2026-11-12T12:00:00.000',
};

void main() {
  group('fetchOrders tolerates one malformed order', () {
    test('skips the bad order and keeps the good ones', () async {
      final api = OrderApiClient(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode([
                orderJson('1'),
                orderJson('2', quantity: 'many'),
                {'not': 'an order'},
                'junk',
                orderJson('3'),
              ]),
            ),
            200,
          ),
        ),
      );

      final orders = await api.fetchOrders();

      expect(orders.map((o) => o.id), ['1', '3']);
    });
  });

  group('streamUpdates tolerates one bad event', () {
    test('skips bad events and still delivers the next good one', () async {
      final api = OrderApiClient(
        client: MockClient.streaming((request, body) async {
          final events = [
            ': connected\n\n',
            'data: {not json\n\n',
            'data: ${jsonEncode(orderJson('bad', quantity: 'x'))}\n\n',
            'data: ${jsonEncode(orderJson('good'))}\n\n',
          ];
          return http.StreamedResponse(
            Stream.fromIterable([for (final e in events) utf8.encode(e)]),
            200,
          );
        }),
      );

      final first = await api.streamUpdates().first.timeout(
        const Duration(seconds: 5),
      );

      expect(first.id, 'good');
    });
  });

  group('order text is cleaned for display', () {
    test('customer, item and topping names lose fake line breaks and '
        'hidden marks', () {
      final order = Order.fromJson({
        ...orderJson('1'),
        'customerName': 'Bao\u202E',
        'items': [
          {
            'name': 'Xôi thịt\n0 VNĐ',
            'quantity': 1,
            'price': 25000,
            'toppings': [
              {'name': 'Thêm\u200B chả\u2028miễn phí', 'price': 10000},
            ],
          },
        ],
      });

      expect(order.customerName, 'Bao');
      expect(order.items.single.name, 'Xôi thịt 0 VNĐ');
      expect(order.items.single.toppings.single.name, 'Thêm chả miễn phí');
    });
  });
}
