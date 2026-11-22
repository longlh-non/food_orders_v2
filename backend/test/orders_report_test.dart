import 'package:food_orders_backend/orders_report.dart';
import 'package:test/test.dart';

Map<String, dynamic> order(
  String placedAt, {
  String status = 'delivered',
  String? paymentMethod,
  List<Map<String, dynamic>>? items,
}) {
  final map = <String, dynamic>{
    'id': 'order-$placedAt',
    'customerName': 'An',
    'status': status,
    'placedAt': placedAt,
    'items':
        items ??
        [
          {'name': 'Xôi thịt', 'quantity': 1, 'price': 25000},
        ],
  };
  if (paymentMethod != null) map['paymentMethod'] = paymentMethod;
  return map;
}

void main() {
  group('deliveredOrders', () {
    test('only delivered; other statuses excluded', () {
      final orders = [
        order('2026-11-05T10:00:00.000', status: 'awaiting_payment'),
        order('2026-11-05T10:01:00.000', status: 'preparing'),
        order('2026-11-05T10:02:00.000', status: 'ready'),
        order('2026-11-05T10:03:00.000', status: 'delivered'),
        order('2026-11-05T10:04:00.000', status: 'cancelled'),
      ];
      final result = deliveredOrders(orders, '2026-11');
      expect(result, hasLength(1));
      expect(result.single.day, '2026-11-05');
    });

    test('only the month\'s orders', () {
      final orders = [
        order('2026-10-31T23:59:59.999'),
        order('2026-11-01T00:00:00.000'),
        order('2026-11-30T23:59:59.999'),
        order('2026-12-01T00:00:00.000'),
      ];
      final result = deliveredOrders(orders, '2026-11');
      expect(result.map((o) => o.day), ['2026-11-01', '2026-11-30']);
    });

    test('method: bank_transfer, cash, missing (cash), and an unknown '
        'value (cash, PAY6)', () {
      final orders = [
        order('2026-11-05T10:00:00.000', paymentMethod: 'bank_transfer'),
        order('2026-11-05T10:01:00.000', paymentMethod: 'cash'),
        order('2026-11-05T10:02:00.000'),
        order('2026-11-05T10:03:00.000', paymentMethod: 'something-else'),
      ];
      final result = deliveredOrders(orders, '2026-11');
      expect(result.map((o) => o.method), [
        'bank_transfer',
        'cash',
        'cash',
        'cash',
      ]);
    });

    test('an explicit null payment method also counts as cash', () {
      final o = order('2026-11-05T10:00:00.000', paymentMethod: null);
      o['paymentMethod'] = null;
      expect(deliveredOrders([o], '2026-11').single.method, 'cash');
    });

    test('invalid month throws ArgumentError', () {
      expect(() => deliveredOrders(const [], '2026-13'), throwsArgumentError);
    });
  });

  group('orderTotal', () {
    test('quantity x (price + toppings), summed over lines', () {
      final total = orderTotal(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {
              'name': 'Xôi thịt',
              'quantity': 2,
              'price': 25000,
              'toppings': [
                {'name': 'Thêm chả', 'price': 10000},
              ],
            },
            {'name': 'Trà đá', 'quantity': 1, 'price': 4000},
          ],
        ),
      );
      expect(total, 2 * (25000 + 10000) + 4000);
    });

    test('no toppings field', () {
      expect(
        orderTotal(
          order(
            '2026-11-05T10:00:00.000',
            items: [
              {'name': 'Trà đá', 'quantity': 3, 'price': 4000},
            ],
          ),
        ),
        12000,
      );
    });

    test('the same topping twice on one line counts twice', () {
      final total = orderTotal(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {
              'name': 'Xôi thịt',
              'quantity': 1,
              'price': 25000,
              'toppings': [
                {'name': 'Thêm chả', 'price': 10000},
                {'name': 'Thêm chả', 'price': 10000},
              ],
            },
          ],
        ),
      );
      expect(total, 25000 + 10000 + 10000);
    });

    test('an old order stored with no id and no toppings key', () {
      final total = orderTotal({
        'customerName': 'An',
        'status': 'delivered',
        'placedAt': '2026-11-05T10:00:00.000',
        'items': [
          {'name': 'Trà đá', 'quantity': 2, 'price': 4000},
        ],
      });
      expect(total, 8000);
    });

    test('a non-whole price (old USD test order) is counted as non-whole', () {
      final o = order(
        '2026-11-05T10:00:00.000',
        items: [
          {'name': 'Coffee', 'quantity': 1, 'price': 9.5},
        ],
      );
      expect(orderTotal(o), 9.5);
      final reportOrders = deliveredOrders([o], '2026-11');
      expect(nonWholeOrders(reportOrders), 1);
    });

    test('nonWholeOrders counts only non-whole totals', () {
      final orders = deliveredOrders([
        order('2026-11-01T10:00:00.000'), // 25000, whole
        order(
          '2026-11-02T10:00:00.000',
          items: [
            {'name': 'Coffee', 'quantity': 1, 'price': 9.5},
          ],
        ),
      ], '2026-11');
      expect(nonWholeOrders(orders), 1);
    });

    test('a double quantity from JSON (e.g. 2.0) is not treated as '
        'non-whole', () {
      final total = orderTotal(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {'name': 'Trà đá', 'quantity': 2.0, 'price': 4000},
          ],
        ),
      );
      expect(total, 8000);
      expect(total, isA<num>());
    });
  });

  group('describeOrder', () {
    test('the example: quantity above 1, one topping, then a plain line', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {
              'name': 'Xôi thịt',
              'quantity': 2,
              'price': 25000,
              'toppings': [
                {'name': 'Thêm chả', 'price': 10000},
              ],
            },
            {'name': 'Trà đá', 'quantity': 1, 'price': 4000},
          ],
        ),
      );
      expect(text, '2 Xôi thịt (Thêm chả), Trà đá');
    });

    test('quantity 1 has no prefix', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {'name': 'Trà đá', 'quantity': 1, 'price': 4000},
          ],
        ),
      );
      expect(text, 'Trà đá');
    });

    test('two toppings, joined by ", " inside the brackets', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {
              'name': 'Xôi thịt',
              'quantity': 1,
              'price': 25000,
              'toppings': [
                {'name': 'Thêm chả', 'price': 10000},
                {'name': 'Thêm trứng tráng', 'price': 8000},
              ],
            },
          ],
        ),
      );
      expect(text, 'Xôi thịt (Thêm chả, Thêm trứng tráng)');
    });

    test('a name with a newline becomes a single space, not shortened', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {'name': 'Xôi\nthịt', 'quantity': 1, 'price': 25000},
          ],
        ),
      );
      expect(text, 'Xôi thịt');
      expect(text.length, 'Xôi\nthịt'.length);
    });

    test('a C1 control character also becomes a single space', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {'name': 'Xôi\x85thịt', 'quantity': 1, 'price': 25000},
          ],
        ),
      );
      expect(text, 'Xôi thịt');
    });

    test('a topping taken twice on one line is written twice', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {
              'name': 'Xôi thịt',
              'quantity': 1,
              'price': 25000,
              'toppings': [
                {'name': 'Thêm chả', 'price': 10000},
                {'name': 'Thêm chả', 'price': 10000},
              ],
            },
          ],
        ),
      );
      expect(text, 'Xôi thịt (Thêm chả, Thêm chả)');
    });

    test('Vietnamese text is unchanged', () {
      final text = describeOrder(
        order(
          '2026-11-05T10:00:00.000',
          items: [
            {'name': 'Trứng ngải cứu', 'quantity': 1, 'price': 15000},
          ],
        ),
      );
      expect(text, 'Trứng ngải cứu');
    });
  });

  group('daysInMonth', () {
    test('28, 29 (leap), 30 and 31', () {
      expect(daysInMonth('2026-02'), 28);
      expect(daysInMonth('2028-02'), 29);
      expect(daysInMonth('2026-04'), 30);
      expect(daysInMonth('2026-01'), 31);
      // December: month+1 must roll over into next year, not throw or
      // wrap to month 13 of the same year.
      expect(daysInMonth('2026-12'), 31);
    });

    test('invalid month throws ArgumentError', () {
      expect(() => daysInMonth('2026-13'), throwsArgumentError);
    });
  });

  group('dailyTotals', () {
    test('every day of the month is present, empty days show 0', () {
      final days = dailyTotals(const [], '2026-02');
      expect(days, hasLength(28));
      expect(days.first.day, '2026-02-01');
      expect(days.last.day, '2026-02-28');
      for (final day in days) {
        expect(day.cash, 0);
        expect(day.transfer, 0);
        expect(day.total, 0);
        expect(day.orders, isEmpty);
      }
    });

    test('cash and transfer are split', () {
      final orders = deliveredOrders([
        order('2026-11-05T10:00:00.000', paymentMethod: 'cash'),
        order('2026-11-05T10:01:00.000', paymentMethod: 'bank_transfer'),
      ], '2026-11');
      final day = dailyTotals(
        orders,
        '2026-11',
      ).firstWhere((d) => d.day == '2026-11-05');
      expect(day.cash, 25000);
      expect(day.transfer, 25000);
      expect(day.total, 50000);
    });

    test('an order with no payment method counts as cash', () {
      final orders = deliveredOrders([
        order('2026-11-05T10:00:00.000'),
      ], '2026-11');
      final day = dailyTotals(
        orders,
        '2026-11',
      ).firstWhere((d) => d.day == '2026-11-05');
      expect(day.cash, 25000);
      expect(day.transfer, 0);
    });

    test('several orders on one day sum correctly, oldest first', () {
      final orders = deliveredOrders([
        order(
          '2026-11-05T12:00:00.000',
          items: [
            {'name': 'B', 'quantity': 1, 'price': 2000},
          ],
        ),
        order(
          '2026-11-05T09:00:00.000',
          items: [
            {'name': 'A', 'quantity': 1, 'price': 1000},
          ],
        ),
        order(
          '2026-11-05T15:00:00.000',
          items: [
            {'name': 'C', 'quantity': 1, 'price': 3000},
          ],
        ),
      ], '2026-11');
      final day = dailyTotals(
        orders,
        '2026-11',
      ).firstWhere((d) => d.day == '2026-11-05');
      expect(day.total, 6000);
      expect(day.orders.map((o) => o.description), ['A', 'B', 'C']);
    });
  });

  group('daysWithOrders', () {
    test('only non-empty days, in date order', () {
      final orders = deliveredOrders([
        order('2026-11-20T10:00:00.000'),
        order('2026-11-03T10:00:00.000'),
      ], '2026-11');
      final days = daysWithOrders(orders, '2026-11');
      expect(days.map((d) => d.day), ['2026-11-03', '2026-11-20']);
      for (final day in days) {
        expect(day.orders, isNotEmpty);
      }
    });

    test('a month with no delivered orders returns no days', () {
      expect(daysWithOrders(const [], '2026-11'), isEmpty);
    });
  });
}
