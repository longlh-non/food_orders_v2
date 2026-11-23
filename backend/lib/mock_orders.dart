import 'dart:math';

import 'orders_api.dart'
    show
        maxIdLength,
        maxItemsPerOrder,
        maxNameLength,
        maxPrice,
        maxQuantity,
        maxToppingsPerItem,
        orderStatuses,
        paymentBankTransfer,
        paymentCash,
        paymentMethods;
import 'orders_export.dart' show isValidMonth;

/// Dev tool only (`bin/seed_mock_orders.dart`): builds realistic, already
/// settled orders for one month, so the two Excel reports have data to show.
/// Pure function: no database, no files, no clock (the caller passes the
/// timestamp for the ids).

/// Fixed list of plausible Vietnamese customer names.
const mockCustomerNames = [
  'Nguyễn Văn An',
  'Trần Thị Bích',
  'Lê Hoàng Nam',
  'Phạm Thu Hà',
  'Hoàng Minh Tuấn',
  'Vũ Thị Lan',
  'Đặng Quốc Bảo',
  'Bùi Ngọc Anh',
  'Đỗ Thanh Hương',
  'Ngô Đức Huy',
  'Dương Khánh Linh',
  'Lý Gia Hân',
  'Phan Văn Dũng',
  'Võ Thị Mai',
  'Trương Quang Vinh',
  'Đinh Thị Ngọc',
];

/// Rows for `INSERT INTO orders`, in the `Order.toJson()` shape: `id`,
/// `customerName`, `status` (`delivered` or `cancelled` only), `placedAt`,
/// `items`, `paymentMethod`, `paymentDueAt` (always null: settled orders).
///
/// Every day of [month] (`YYYY-MM`) gets orders except one seed-chosen day,
/// which gets none. Two or three more rows sit just outside the month (last
/// day before, first day after). [menuItems] / [toppings] are in the
/// `GET /menu` / `GET /toppings` shape; an item or topping that breaks the
/// order limits is skipped. With no usable menu item the result is empty.
List<Map<String, dynamic>> buildMockOrders({
  required String month,
  required List<Map<String, dynamic>> menuItems,
  required List<Map<String, dynamic>> toppings,
  required int seed,
  required int runTimestampMs,
}) {
  if (!isValidMonth(month)) {
    throw ArgumentError.value(month, 'month', 'must be YYYY-MM');
  }
  final items = menuItems.where(_validEntry).toList();
  if (items.isEmpty) return [];
  final tops = toppings.where(_validEntry).toList();

  final rnd = Random(seed);
  final year = int.parse(month.substring(0, 4));
  final monthNumber = int.parse(month.substring(5, 7));
  final days = DateTime(year, monthNumber + 1, 0).day;
  final emptyDay = 1 + rnd.nextInt(days);

  // (date, drafted order) pairs; ids are assigned after sorting.
  final drafts = <Map<String, dynamic>>[];
  for (var d = 1; d <= days; d++) {
    if (d == emptyDay) continue;
    final count = 5 + rnd.nextInt(11);
    for (var i = 0; i < count; i++) {
      drafts.add(_draft(rnd, DateTime(year, monthNumber, d), items, tops));
    }
  }
  // Just outside the month: the last day before, the first day after (x2).
  drafts.add(_draft(rnd, DateTime(year, monthNumber, 0), items, tops));
  drafts.add(_draft(rnd, DateTime(year, monthNumber + 1, 1), items, tops));
  drafts.add(_draft(rnd, DateTime(year, monthNumber + 1, 1), items, tops));

  drafts.sort(
    (a, b) => (a['placedAt'] as String).compareTo(b['placedAt'] as String),
  );
  for (var i = 0; i < drafts.length; i++) {
    drafts[i]['id'] = 'mock-$runTimestampMs-$i';
  }
  return drafts;
}

bool _validEntry(Map<String, dynamic> e) {
  final name = e['name'];
  final price = e['price'];
  return name is String &&
      name.isNotEmpty &&
      name.length <= maxNameLength &&
      price is num &&
      price == price.truncate() &&
      price >= 0 &&
      price <= maxPrice;
}

Map<String, dynamic> _draft(
  Random rnd,
  DateTime day,
  List<Map<String, dynamic>> items,
  List<Map<String, dynamic>> tops,
) {
  final lineCount = min(
    min(1 + rnd.nextInt(4), items.length),
    maxItemsPerOrder,
  );
  final pool = [...items]..shuffle(rnd);
  final lines = <Map<String, dynamic>>[];
  for (final menu in pool.take(lineCount)) {
    final roll = rnd.nextInt(100);
    final quantity = roll < 70
        ? 1
        : roll < 90
        ? 2
        : roll < 98
        ? 3 + rnd.nextInt(2)
        : 5 + rnd.nextInt(2);
    final line = <String, dynamic>{
      if (menu['id'] is String && (menu['id'] as String).isNotEmpty)
        'id': menu['id'],
      'name': menu['name'],
      'quantity': min(quantity, maxQuantity),
      'price': (menu['price'] as num).toInt(),
    };
    if (menu['allowToppings'] == true &&
        tops.isNotEmpty &&
        rnd.nextInt(10) < 4) {
      final n = min(1 + rnd.nextInt(2), min(tops.length, maxToppingsPerItem));
      final picked = [...tops]..shuffle(rnd);
      line['toppings'] = [
        for (final t in picked.take(n))
          {
            if (t['id'] is String && (t['id'] as String).isNotEmpty)
              'id': t['id'],
            'name': t['name'],
            'price': (t['price'] as num).toInt(),
          },
      ];
    }
    lines.add(line);
  }

  final placed = DateTime(
    day.year,
    day.month,
    day.day,
    7 + rnd.nextInt(14),
    rnd.nextInt(60),
    rnd.nextInt(60),
  );
  final cancelled = rnd.nextInt(100) < 15;
  final status = cancelled ? 'cancelled' : 'delivered';
  final method = rnd.nextInt(100) < 40 ? paymentBankTransfer : paymentCash;
  assert(orderStatuses.contains(status) && paymentMethods.contains(method));
  assert('mock-0-0'.length <= maxIdLength);
  return {
    'id': '',
    'customerName': mockCustomerNames[rnd.nextInt(mockCustomerNames.length)],
    'status': status,
    'placedAt': placed.toIso8601String(),
    'items': lines,
    'paymentMethod': method,
    'paymentDueAt': null,
  };
}
