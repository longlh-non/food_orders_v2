import 'orders_export.dart' show isValidMonth, ordersInMonth;

/// The numbers behind the two Excel reports (`backend-report-summary-xlsx`,
/// `backend-report-detail-xlsx`): which delivered orders fall in a month,
/// grouped by day, cash versus bank transfer. Pure functions only: no
/// database, no files, no spreadsheet, no `dart:io`. The layout cards only
/// draw what this returns.
///
/// Reuses [isValidMonth] and [ordersInMonth] from `orders_export.dart`
/// (same month rule as the CSV export: `placedAt` as written, RPT3) rather
/// than copying them. The CSV code itself is untouched.

/// One delivered order, in the shape the reports need. [method] is always
/// `'cash'` or `'bank_transfer'` (an order with no payment method counts
/// as cash, PAY6).
class ReportOrder {
  const ReportOrder({
    required this.day,
    required this.description,
    required this.total,
    required this.method,
  });

  /// `YYYY-MM-DD`, the day in `placedAt` as written (RPT3): the customer
  /// device's local date, taken as shop time, no time-zone conversion.
  final String day;

  /// [describeOrder]'s result for this order.
  final String description;

  /// [orderTotal]'s result for this order.
  final num total;

  final String method;
}

/// One calendar day of a month's report: the delivered orders placed that
/// day (oldest first) and their totals. Every day of the month gets one of
/// these from [dailyTotals], even with no orders (the summary report shows
/// all of them); [daysWithOrders] then drops the empty ones for the detail
/// report.
class DayTotals {
  const DayTotals({
    required this.day,
    required this.cash,
    required this.transfer,
    required this.orders,
  });

  /// `YYYY-MM-DD`.
  final String day;

  final num cash;
  final num transfer;

  /// This day's delivered orders, oldest first.
  final List<ReportOrder> orders;

  num get total => cash + transfer;
}

/// Delivered orders placed in [month] (`YYYY-MM`), oldest first (ties kept
/// in [orders]' own order, via [ordersInMonth]). Every other status
/// (`awaiting_payment`, `preparing`, `ready`, `cancelled`) is excluded.
List<ReportOrder> deliveredOrders(
  List<Map<String, dynamic>> orders,
  String month,
) {
  _checkMonth(month);
  return [
    for (final order in ordersInMonth(orders, month))
      if (order['status'] == 'delivered')
        ReportOrder(
          day: _day(order['placedAt'] as String),
          description: describeOrder(order),
          total: orderTotal(order),
          method: order['paymentMethod'] == 'bank_transfer'
              ? 'bank_transfer'
              : 'cash',
        ),
  ];
}

/// The `YYYY-MM-DD` date prefix of a stored `placedAt`. Real orders always
/// pass POST validation (`YYYY-MM-DDT...`, at least 10 characters), but a
/// hand-edited database row might not — a short string is kept whole
/// rather than throwing a `RangeError`, matching `orders_export.dart`'s own
/// defensive read of the same field.
String _day(String placedAt) =>
    placedAt.length >= 10 ? placedAt.substring(0, 10) : placedAt;

/// The whole order's amount: the sum over its lines of
/// `quantity x (price + sum of topping prices)`. Works for an old order
/// stored with no `id` or `toppings` on an item.
num orderTotal(Map order) {
  num total = 0;
  for (final item in (order['items'] as List).cast<Map<String, dynamic>>()) {
    total += (item['quantity'] as num) * _unitPrice(item);
  }
  return total;
}

num _unitPrice(Map<String, dynamic> item) {
  final toppings = ((item['toppings'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  return toppings.fold<num>(
    item['price'] as num,
    (sum, t) => sum + (t['price'] as num),
  );
}

/// The order's lines, joined by `, `: a line is the item's name, with the
/// quantity first (`2 Xôi thịt`) only when it's above 1, and its toppings
/// after it in brackets (`Xôi thịt (Thêm chả, Thêm thịt)`, in storage order
/// — a topping taken twice on one line is written twice). Newlines and
/// other control characters (C0 and C1, including DEL) in a name become a
/// single space each; the text is never shortened.
String describeOrder(Map order) => (order['items'] as List)
    .cast<Map<String, dynamic>>()
    .map(_describeItem)
    .join(', ');

String _describeItem(Map<String, dynamic> item) {
  final quantity = (item['quantity'] as num).toInt();
  final prefix = quantity > 1 ? '$quantity ' : '';
  final name = _oneLine(item['name'] as String);
  final toppings = ((item['toppings'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final toppingText = toppings.isEmpty
      ? ''
      : ' (${toppings.map((t) => _oneLine(t['name'] as String)).join(', ')})';
  return '$prefix$name$toppingText';
}

final _controlChars = RegExp(r'[\x00-\x1F\x7F-\x9F]');

String _oneLine(String text) => text.replaceAll(_controlChars, ' ');

/// The number of days in [month] (`YYYY-MM`), leap years included.
int daysInMonth(String month) {
  _checkMonth(month);
  final year = int.parse(month.substring(0, 4));
  final monthNumber = int.parse(month.substring(5, 7));
  // Day 0 of next month = the last day of this one.
  return DateTime(year, monthNumber + 1, 0).day;
}

/// One entry for every calendar day of [month] (the summary report shows
/// all of them, even with 0), each with that day's delivered [orders] (as
/// returned by [deliveredOrders], oldest first) split into [DayTotals.cash]
/// and [DayTotals.transfer].
List<DayTotals> dailyTotals(List<ReportOrder> orders, String month) {
  final byDay = <String, List<ReportOrder>>{};
  for (final order in orders) {
    (byDay[order.day] ??= []).add(order);
  }
  final totalDays = daysInMonth(month);
  return [for (var d = 1; d <= totalDays; d++) _dayTotals(month, d, byDay)];
}

DayTotals _dayTotals(
  String month,
  int day,
  Map<String, List<ReportOrder>> byDay,
) {
  final key = '$month-${day.toString().padLeft(2, '0')}';
  final dayOrders = byDay[key] ?? const [];
  num cash = 0, transfer = 0;
  for (final order in dayOrders) {
    if (order.method == 'bank_transfer') {
      transfer += order.total;
    } else {
      cash += order.total;
    }
  }
  return DayTotals(day: key, cash: cash, transfer: transfer, orders: dayOrders);
}

/// Only the days of [month] that have at least one delivered order, in
/// date order — what the detail report shows (RPT2: empty days are
/// skipped, unlike the summary).
List<DayTotals> daysWithOrders(List<ReportOrder> orders, String month) => [
  for (final day in dailyTotals(orders, month))
    if (day.orders.isNotEmpty) day,
];

/// How many of [orders] have a total that isn't a whole number (old USD
/// test orders, e.g. `9.5`) — so the export route can warn the owner. The
/// reports themselves never round or rewrite money.
int nonWholeOrders(List<ReportOrder> orders) =>
    orders.where((o) => o.total != o.total.truncate()).length;

void _checkMonth(String month) {
  if (!isValidMonth(month)) {
    throw ArgumentError.value(month, 'month', 'must be YYYY-MM');
  }
}
