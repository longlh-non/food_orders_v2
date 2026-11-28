import 'orders_report.dart' show DayTotals;
import 'xlsx_writer.dart';

/// The monthly "chi tiết" (detail) report: every finished order of the
/// month, one row each, grouped by day. Pure: no database, no file, no
/// route, no `dart:io`.
///
/// [days] is what `daysWithOrders` (`orders_report.dart`) returns: one
/// entry per day that has at least one finished order (RPT2: empty days
/// are already dropped before this runs), each with its orders oldest
/// first. This module only draws the days it is handed; it never calls
/// `finishedOrders`, `dailyTotals`, `daysWithOrders` or `describeOrder`
/// itself, so it never parses a raw stored order and can't hit a malformed
/// row — that only happens one layer up, in whatever builds [days].

const _base = CellStyle(fontSize: 18);
final _title = _base.copyWith(bold: true);

/// `Ngày tháng năm` / `Giao dịch`: bold, centred both ways, wrapped — the
/// two-row-tall header cells (merged `A2:A3`, `B2:B3`).
final _header = _base
    .copyWith(
      bold: true,
      horizontal: HAlign.center,
      vertical: VAlign.center,
      wrap: true,
    )
    .withAllBorders;

/// `Số tiền` / `Tiền mặt` / `Chuyển khoản`: bold, centred horizontally only
/// (one row tall, so vertical centring and wrap don't apply).
final _headerCenter = _base
    .copyWith(bold: true, horizontal: HAlign.center)
    .withAllBorders;

/// A plain bordered table cell with nothing in it.
final _tableCell = _base.withAllBorders;

/// `Ngày DD/MM/YYYY`: bold, left-aligned.
final _dayHeader = _base.copyWith(bold: true).withAllBorders;

/// An order's description: always wrapped (RPT7), whatever its length.
final _description = _base.copyWith(wrap: true).withAllBorders;

/// A cash or transfer amount cell on an order row.
final _amount = _base
    .copyWith(numberFormat: NumberFormat.thousands)
    .withAllBorders;

/// `Cộng ngày DD/MM/YYYY`: bold.
final _sumLabel = _base.copyWith(bold: true).withAllBorders;

/// The day's cash/transfer sum formulas: bold, thousands format.
final _sumAmount = _base
    .copyWith(bold: true, numberFormat: NumberFormat.thousands)
    .withAllBorders;

/// Column default styles: every column is Calibri 18; C and D also default
/// to the thousands format.
const _plainColumn = CellStyle(fontSize: 18);
const _moneyColumn = CellStyle(
  fontSize: 18,
  numberFormat: NumberFormat.thousands,
);

final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// Builds the `.xlsx` bytes of the detail report for [month] (`YYYY-MM`)
/// from [days]. A month with no finished orders (`days` empty) gives just
/// the header rows (1-4).
List<int> buildDetailReport({
  required String month,
  required List<DayTotals> days,
}) {
  if (!_monthPattern.hasMatch(month)) {
    throw ArgumentError.value(month, 'month', 'must be YYYY-MM');
  }

  final rows = <XlsxRow>[
    XlsxRow(
      1,
      height: 24,
      cells: [XlsxCell.text(_monthTitle(month), style: _title)],
    ),
    XlsxRow(
      2,
      cells: [
        XlsxCell.text('Ngày tháng năm', style: _header),
        XlsxCell.text('Giao dịch', style: _header),
        XlsxCell.text('Số tiền', style: _headerCenter),
        XlsxCell.empty(style: _headerCenter),
      ],
    ),
    XlsxRow(
      3,
      cells: [
        XlsxCell.empty(style: _header),
        XlsxCell.empty(style: _header),
        XlsxCell.text('Tiền mặt', style: _headerCenter),
        XlsxCell.text('Chuyển khoản', style: _headerCenter),
      ],
    ),
    // Spacing row between the header and the first day. Needs a cell (even
    // empty) in every column so the writer keeps the row and the borders
    // show on A:D.
    XlsxRow(
      4,
      cells: [
        XlsxCell.empty(style: _tableCell),
        XlsxCell.empty(style: _tableCell),
        XlsxCell.empty(style: _tableCell),
        XlsxCell.empty(style: _tableCell),
      ],
    ),
  ];

  var row = 5;
  for (final day in days) {
    final s = row;
    final n = day.orders.length;
    final e = s + n;
    final dayLabel = _formatDay(day.day);

    rows.add(
      XlsxRow(
        s,
        cells: [
          XlsxCell.text('Ngày $dayLabel', style: _dayHeader),
          XlsxCell.empty(style: _tableCell),
          XlsxCell.empty(style: _tableCell),
          XlsxCell.empty(style: _tableCell),
        ],
      ),
    );

    for (var i = 0; i < n; i++) {
      final order = day.orders[i];
      final cash = order.method != 'bank_transfer';
      rows.add(
        XlsxRow(
          s + 1 + i,
          cells: [
            XlsxCell.empty(style: _tableCell),
            XlsxCell.text(order.description, style: _description),
            cash
                ? XlsxCell.number(order.total, style: _amount)
                : XlsxCell.empty(style: _tableCell),
            cash
                ? XlsxCell.empty(style: _tableCell)
                : XlsxCell.number(order.total, style: _amount),
          ],
        ),
      );
    }

    final sumRow = e + 1;
    rows.add(
      XlsxRow(
        sumRow,
        cells: [
          XlsxCell.empty(style: _tableCell),
          XlsxCell.text('Cộng ngày $dayLabel', style: _sumLabel),
          XlsxCell.formula('SUM(C${s + 1}:C$e)', day.cash, style: _sumAmount),
          XlsxCell.formula(
            'SUM(D${s + 1}:D$e)',
            day.transfer,
            style: _sumAmount,
          ),
        ],
      ),
    );
    row = sumRow + 1;
  }

  final sheet = XlsxSheet(
    'Sheet1',
    columns: const [
      XlsxColumn(1, 1, 26.109375, style: _plainColumn),
      XlsxColumn(2, 2, 39.77734375, style: _plainColumn),
      XlsxColumn(3, 3, 31.5546875, style: _moneyColumn),
      XlsxColumn(4, 4, 28.6640625, style: _moneyColumn),
      XlsxColumn(5, 16384, 8.88671875, style: _plainColumn),
    ],
    rows: rows,
    merges: const ['A2:A3', 'B2:B3', 'C2:D2'],
  );
  return XlsxWorkbook([sheet]).toBytes();
}

/// `Chi tiết tháng M/YYYY`, [month] without a leading zero.
String _monthTitle(String month) =>
    'Chi tiết tháng ${int.parse(month.substring(5, 7))}/'
    '${month.substring(0, 4)}';

/// `DD/MM/YYYY` from a `YYYY-MM-DD` day, zero-padded (both are already
/// zero-padded in [DayTotals.day]).
String _formatDay(String day) =>
    '${day.substring(8, 10)}/${day.substring(5, 7)}/${day.substring(0, 4)}';
