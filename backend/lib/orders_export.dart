import 'dart:convert';

/// Monthly orders export: turns orders (the `Order.toJson()` shape stored by
/// the backend) into the bytes of a CSV file that Excel opens correctly.
///
/// Pure functions only: no database, no files, no network. A separate
/// command (card `backend-orders-month-export-cli`) wires them to the
/// database.

/// The column headers, in Vietnamese because the file is for the shop.
const exportHeader = [
  'Ngày',
  'Giờ',
  'Mã đơn',
  'Khách',
  'Món',
  'Số lượng',
  'Đơn giá',
  'Topping',
  'Thành tiền',
  'Trạng thái',
];

final _month = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// True for exactly `YYYY-MM` with a month from 01 to 12.
bool isValidMonth(String s) => _month.hasMatch(s);

/// The orders placed in [month] (`YYYY-MM`), oldest first. Orders with the
/// same `placedAt` keep their input order.
///
/// `placedAt` is the customer device's local time with no time zone, taken
/// to be the shop's local time (Asia/Ho_Chi_Minh). It is compared as text,
/// never converted. Known limit: a value ending in `Z` or with an offset is
/// still matched by its text prefix.
List<Map<String, dynamic>> ordersInMonth(
  List<Map<String, dynamic>> orders,
  String month,
) {
  final prefix = '$month-';
  final matching = <(int, Map<String, dynamic>)>[
    for (final (index, order) in orders.indexed)
      if (order['placedAt'] case final String placedAt
          when placedAt.startsWith(prefix))
        (index, order),
  ];
  // List.sort isn't stable, so break ties by the original position.
  matching.sort((a, b) {
    final byTime = (a.$2['placedAt'] as String).compareTo(
      b.$2['placedAt'] as String,
    );
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final (_, order) in matching) order];
}

/// One row per order line, in [exportHeader] order: date, time, order id,
/// customer, item, quantity, unit price (base + toppings), toppings, line
/// total, status. Money and quantity stay numbers so Excel can add them up.
/// Every text cell is passed through [neutralise].
List<List<Object>> exportRows(List<Map<String, dynamic>> orders) => [
  for (final order in orders)
    for (final item in (order['items'] as List).cast<Map<String, dynamic>>())
      _row(order, item),
];

List<Object> _row(Map<String, dynamic> order, Map<String, dynamic> item) {
  final placedAt = order['placedAt'] as String;
  final toppings = ((item['toppings'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  final quantity = item['quantity'] as num;
  final unitPrice = toppings.fold<num>(
    item['price'] as num,
    (sum, t) => sum + (t['price'] as num),
  );
  return [
    // Text cells, so they're neutralised too. Today the backend only stores
    // dates starting with a digit, but old rows or a looser validator must
    // not be able to put a formula here.
    neutralise(placedAt.length >= 10 ? placedAt.substring(0, 10) : placedAt),
    neutralise(
      placedAt.length >= 16 && placedAt[10] == 'T'
          ? placedAt.substring(11, 16)
          : '',
    ),
    neutralise(order['id'] as String),
    neutralise(order['customerName'] as String),
    neutralise(item['name'] as String),
    quantity,
    unitPrice,
    neutralise([for (final t in toppings) t['name'] as String].join('; ')),
    unitPrice * quantity,
    neutralise(order['status'] as String),
  ];
}

const _formulaStarts = {'=', '+', '-', '@', '\t', '\r'};

/// Stops text from running as a formula when Excel opens the file
/// (CSV/formula injection): text starting with `=`, `+`, `-`, `@`, a tab or
/// a carriage return, after any leading spaces, gets a leading `'`.
/// Only for text cells: numbers must stay numbers.
String neutralise(String cell) {
  final afterSpaces = cell.replaceFirst(RegExp('^ +'), '');
  if (afterSpaces.isNotEmpty && _formulaStarts.contains(afterSpaces[0])) {
    return "'$cell";
  }
  return cell;
}

/// The file's bytes: the UTF-8 byte order mark (so Excel reads Vietnamese
/// letters correctly), then `sep=;` when [sepLine] is set (so Excel splits
/// columns on `;` whatever its regional setting), then the header and the
/// rows. Lines end in CRLF.
///
/// Text is quoted when it contains the delimiter, `"`, CR or LF, with `"`
/// doubled. Numbers are written bare: whole numbers without decimals or
/// thousands separators (`25000`), anything else as Dart writes it (`9.5`).
List<int> csvBytes(
  List<List<Object>> rows, {
  String delimiter = ';',
  bool sepLine = true,
}) {
  final text = StringBuffer();
  if (sepLine) text.write('sep=$delimiter\r\n');
  for (final row in [exportHeader, ...rows]) {
    text.write(row.map((cell) => _cell(cell, delimiter)).join(delimiter));
    text.write('\r\n');
  }
  return [0xEF, 0xBB, 0xBF, ...utf8.encode(text.toString())];
}

String _cell(Object cell, String delimiter) {
  if (cell is num) {
    return cell.isFinite && cell == cell.truncate()
        ? cell.truncate().toString()
        : cell.toString();
  }
  final text = cell.toString();
  final needsQuotes =
      text.contains(delimiter) ||
      text.contains('"') ||
      text.contains('\r') ||
      text.contains('\n');
  return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
}

/// What the export command prints after writing the file.
class ExportSummary {
  const ExportSummary({
    required this.orders,
    required this.lines,
    required this.totalsByStatus,
    required this.grandTotal,
    required this.nonWholeLines,
  });

  final int orders;
  final int lines;

  /// VND per status, e.g. `{'delivered': 125000, 'cancelled': 25000}`.
  final Map<String, num> totalsByStatus;

  /// Every status except `cancelled`.
  final num grandTotal;

  /// Lines whose price or quantity isn't a whole number. Real VND data is
  /// always whole, so these are most likely old USD test orders.
  final int nonWholeLines;
}

ExportSummary summarise(List<Map<String, dynamic>> orders) {
  final totals = <String, num>{};
  var lines = 0;
  var nonWhole = 0;
  for (final order in orders) {
    final status = order['status'] as String;
    for (final row in exportRows([order])) {
      lines++;
      final quantity = row[5] as num;
      final unitPrice = row[6] as num;
      final lineTotal = row[8] as num;
      if (quantity != quantity.truncate() ||
          unitPrice != unitPrice.truncate()) {
        nonWhole++;
      }
      totals[status] = (totals[status] ?? 0) + lineTotal;
    }
  }
  final grand = totals.entries
      .where((e) => e.key != 'cancelled')
      .fold<num>(0, (sum, e) => sum + e.value);
  return ExportSummary(
    orders: orders.length,
    lines: lines,
    totalsByStatus: totals,
    grandTotal: grand,
    nonWholeLines: nonWhole,
  );
}
