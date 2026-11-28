import 'orders_report.dart' show DayTotals;
import 'shop_settings.dart' show ShopSettings;
import 'xlsx_writer.dart';

/// The monthly "báo cáo tổng hợp" (summary) report: two sheets, `gộp`
/// (every day's cash + transfer together) and `tách` (cash and transfer
/// apart). Pure: no database, no file, no route, no `dart:io`.
///
/// [days] is what `dailyTotals` (`orders_report.dart`) returns: one entry
/// per calendar day of the month, in date order, even for a day with no
/// finished order (RPT1: every day is shown, unlike the detail report).
/// This module only draws the days it is handed; it never calls
/// `finishedOrders`, `dailyTotals`, `daysInMonth` or `daysWithOrders`
/// itself, so it never parses a raw stored order and can't hit a malformed
/// row — that only happens one layer up, in whatever builds [days].
///
/// Every `XlsxCell.formula` string below is built only from cell
/// references and the day count (never from order or shop text).

const _base = CellStyle(fontSize: 18);
final _bold = _base.copyWith(bold: true);
final _boldCenter = _base.copyWith(bold: true, horizontal: HAlign.center);
final _center = _base.copyWith(horizontal: HAlign.center);

/// Row 7's period line: centred, with the bottom border RPT8 keeps under
/// the title block (the one exception there).
final _period = _center.copyWith(borderBottom: true);

/// The footer date line: italic, centred, with the top border RPT8 keeps
/// above the signature block (the other exception).
final _footerDate = _base.copyWith(
  italic: true,
  horizontal: HAlign.center,
  borderTop: true,
);

/// `SHOP_REPRESENTATIVE`'s own line: bold, Times New Roman 16, centred, no
/// border (part of the signature block).
final _representative = _base.copyWith(
  fontName: 'Times New Roman',
  fontSize: 16,
  bold: true,
  horizontal: HAlign.center,
);

/// A bordered table cell with nothing in it ("the table style" in the
/// card's own words).
final _tableCell = _base.withAllBorders;
final _tableBold = _bold.withAllBorders;
final _tableBoldCenter = _boldCenter.withAllBorders;
final _tableWrapBold = _bold.copyWith(wrap: true).withAllBorders;
final _tableAmount = _base
    .copyWith(numberFormat: NumberFormat.thousands)
    .withAllBorders;

/// `Tổng cộng` (sheet `gộp`): bold, size 20, centred, bordered.
final _totalLabelCenter20 = _tableBold.copyWith(
  fontSize: 20,
  horizontal: HAlign.center,
);

/// `Tổng tháng M` (sheet `tách`, RPT6): bold, size 20, bordered, **not**
/// centred (only the `gộp` label is, per the card).
final _totalLabel20 = _tableBold.copyWith(fontSize: 20);

/// A total-row amount: bold, size 20, thousands format, bordered.
final _totalAmount20 = _tableAmount.copyWith(bold: true, fontSize: 20);

/// One constant description for every day row, on both sheets.
const _description = 'Bán hàng cho khách không biết tên, không lấy hóa đơn';

final _monthPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// Builds the `.xlsx` bytes of the summary report (sheets `gộp` and
/// `tách`) for [month] (`YYYY-MM`) from [days] — one entry per calendar
/// day of that month, oldest first (what `dailyTotals` returns).
///
/// Requires `shop.reportEnabled` (all five `SHOP_*` values set): the title
/// block reads [ShopSettings.shopName], [ShopSettings.taxCode],
/// [ShopSettings.address], [ShopSettings.location] and
/// [ShopSettings.representative] directly, which are `null` otherwise. The
/// caller must gate on [ShopSettings.reportEnabled] first.
List<int> buildSummaryReport({
  required ShopSettings shop,
  required String month,
  required List<DayTotals> days,
}) {
  if (!shop.reportEnabled) {
    throw ArgumentError.value(shop, 'shop', 'reportEnabled must be true');
  }
  if (!_monthPattern.hasMatch(month)) {
    throw ArgumentError.value(month, 'month', 'must be YYYY-MM');
  }
  if (days.isEmpty) {
    throw ArgumentError.value(days, 'days', 'must have at least one day');
  }
  return XlsxWorkbook([
    _sheetGop(shop, month, days),
    _sheetTach(shop, month, days),
  ]).toBytes();
}

// ---------------------------------------------------------------------------
// Sheet 1: `gộp` — every day, one amount (cash + transfer).

XlsxSheet _sheetGop(ShopSettings shop, String month, List<DayTotals> days) {
  final d = days.length;
  final monthNum = _monthNumber(month);
  final year = _year(month);
  final lastDay = _dayOfMonth(days.last.day);

  final rows = <XlsxRow>[
    ..._titleRows(shop, month, columns: 2),
    XlsxRow(
      8,
      cells: [
        XlsxCell.text('Ngày, tháng, năm', style: _tableWrapBold),
        XlsxCell.text('Giao dịch', style: _tableBoldCenter),
        XlsxCell.text('Số tiền', style: _tableBoldCenter),
      ],
    ),
  ];

  for (var i = 0; i < d; i++) {
    final day = days[i];
    rows.add(
      XlsxRow(
        9 + i,
        cells: [
          XlsxCell.text('Ngày ${_formatDmy(day.day)}', style: _tableCell),
          XlsxCell.text(_description, style: _tableCell),
          XlsxCell.number(day.total, style: _tableAmount),
        ],
      ),
    );
  }

  final totalRow = 9 + d;
  num total = 0;
  for (final day in days) {
    total += day.total;
  }
  rows.add(
    XlsxRow(
      totalRow,
      height: 25.8,
      cells: [
        XlsxCell.empty(style: _tableCell),
        XlsxCell.text('Tổng cộng', style: _totalLabelCenter20),
        XlsxCell.formula('SUM(C9:C${8 + d})', total, style: _totalAmount20),
      ],
    ),
  );

  final dateRow = 10 + d;
  rows.add(
    XlsxRow(
      dateRow,
      cells: _rowCells(
        startCol: 3,
        span: 3,
        text: 'Ngày $lastDay tháng $monthNum năm $year',
        style: _footerDate,
      ),
    ),
  );

  final titleRow = 11 + d;
  rows.add(
    XlsxRow(
      titleRow,
      height: 25.8,
      customHeight: true,
      cells: _rowCells(
        startCol: 3,
        span: 3,
        text: 'NGƯỜI ĐẠI DIỆN HỘ KINH DOANH',
        style: _center,
      ),
    ),
  );

  for (var r = 12 + d; r <= 15 + d; r++) {
    rows.add(XlsxRow(r, cells: [XlsxCell.empty(style: _base)]));
  }

  final nameRow = 16 + d;
  rows.add(
    XlsxRow(
      nameRow,
      cells: _rowCells(
        startCol: 3,
        span: 3,
        text: shop.representative!,
        style: _representative,
      ),
    ),
  );

  return XlsxSheet(
    'gộp',
    columns: const [
      XlsxColumn(1, 1, 28.33203125, style: _base),
      XlsxColumn(2, 2, 79.5546875, style: _base),
      XlsxColumn(3, 3, 54, style: _base),
      XlsxColumn(4, 16384, 8.88671875, style: _base),
    ],
    rows: rows,
    merges: [
      'A5:B5',
      'A6:B6',
      'A7:B7',
      'C$dateRow:E$dateRow',
      'C$titleRow:E$titleRow',
      'C$nameRow:E$nameRow',
    ],
  );
}

// ---------------------------------------------------------------------------
// Sheet 2: `tách` — cash and transfer apart.

XlsxSheet _sheetTach(ShopSettings shop, String month, List<DayTotals> days) {
  final d = days.length;
  final monthNum = _monthNumber(month);
  final year = _year(month);
  final lastDay = _dayOfMonth(days.last.day);

  final rows = <XlsxRow>[
    ..._titleRows(shop, month, columns: 3),
    XlsxRow(
      8,
      cells: [
        XlsxCell.text('Ngày, tháng, năm', style: _tableWrapBold),
        XlsxCell.text('Nội dung', style: _tableBoldCenter),
        XlsxCell.text('Số tiền', style: _tableBoldCenter),
        XlsxCell.empty(style: _tableBoldCenter),
        XlsxCell.empty(style: _tableBoldCenter),
      ],
    ),
    XlsxRow(
      9,
      height: 24,
      cells: [
        XlsxCell.empty(style: _tableCell),
        XlsxCell.empty(style: _tableCell),
        XlsxCell.text('Chuyển khoản', style: _tableBoldCenter),
        XlsxCell.text('Tiền mặt', style: _tableBoldCenter),
        XlsxCell.text('Cộng', style: _tableBoldCenter),
      ],
    ),
  ];

  for (var i = 0; i < d; i++) {
    final day = days[i];
    final r = 10 + i;
    rows.add(
      XlsxRow(
        r,
        cells: [
          XlsxCell.text('Ngày ${_formatDmy(day.day)}', style: _tableCell),
          XlsxCell.text(_description, style: _tableCell),
          XlsxCell.number(day.transfer, style: _tableAmount),
          XlsxCell.number(day.cash, style: _tableAmount),
          XlsxCell.formula(
            'D$r+C$r',
            day.cash + day.transfer,
            style: _tableAmount,
          ),
        ],
      ),
    );
  }

  final totalRow = 10 + d;
  final lastDayRow = 9 + d;
  num sumTransfer = 0, sumCash = 0, sumTotal = 0;
  for (final day in days) {
    sumTransfer += day.transfer;
    sumCash += day.cash;
    sumTotal += day.cash + day.transfer;
  }
  rows.add(
    XlsxRow(
      totalRow,
      height: 25.8,
      cells: [
        XlsxCell.text(_tongThang(monthNum), style: _totalLabel20),
        XlsxCell.empty(style: _tableCell),
        XlsxCell.formula(
          'SUM(C10:C$lastDayRow)',
          sumTransfer,
          style: _totalAmount20,
        ),
        XlsxCell.formula(
          'SUM(D10:D$lastDayRow)',
          sumCash,
          style: _totalAmount20,
        ),
        XlsxCell.formula(
          'SUM(E10:E$lastDayRow)',
          sumTotal,
          style: _totalAmount20,
        ),
      ],
    ),
  );

  final dateRow = 11 + d;
  rows.add(
    XlsxRow(
      dateRow,
      cells: _rowCells(
        startCol: 3,
        span: 3,
        text: 'Ngày $lastDay tháng $monthNum năm $year',
        style: _footerDate,
      ),
    ),
  );

  final titleRow = 12 + d;
  rows.add(
    XlsxRow(
      titleRow,
      height: 25.8,
      customHeight: true,
      cells: _rowCells(
        startCol: 3,
        span: 3,
        text: 'NGƯỜI ĐẠI DIỆN HỘ KINH DOANH',
        style: _center,
      ),
    ),
  );

  for (var r = 13 + d; r <= 16 + d; r++) {
    rows.add(XlsxRow(r, cells: [XlsxCell.empty(style: _base)]));
  }

  final nameRow = 17 + d;
  rows.add(
    XlsxRow(
      nameRow,
      cells: _rowCells(
        startCol: 3,
        span: 3,
        text: shop.representative!,
        style: _representative,
      ),
    ),
  );

  return XlsxSheet(
    'tách',
    columns: const [
      XlsxColumn(1, 1, 28.33203125, style: _base),
      XlsxColumn(2, 2, 79.5546875, style: _base),
      XlsxColumn(3, 3, 21.88671875, style: _base),
      XlsxColumn(4, 4, 21.88671875, style: _base),
      XlsxColumn(5, 5, 21.88671875, style: _base),
      XlsxColumn(6, 16384, 8.88671875, style: _base),
    ],
    rows: rows,
    merges: [
      'A5:C5',
      'A6:C6',
      'A7:C7',
      'C8:E8',
      'C$dateRow:E$dateRow',
      'C$titleRow:E$titleRow',
      'C$nameRow:E$nameRow',
    ],
  );
}

// ---------------------------------------------------------------------------
// Shared helpers.

/// Rows 1-7, shared by both sheets: the shop header, the title and the
/// period line. [columns] is how many columns the row-5/6/7 merges span
/// (`A:B` = 2 on `gộp`, `A:C` = 3 on `tách`).
List<XlsxRow> _titleRows(
  ShopSettings shop,
  String month, {
  required int columns,
}) {
  final period = 'Kỳ báo cáo: Tháng ${_monthNumber(month)} năm ${_year(month)}';
  return [
    XlsxRow(1, cells: [XlsxCell.text(shop.shopName!, style: _bold)]),
    XlsxRow(
      2,
      cells: [XlsxCell.text('Mã số thuế: ${shop.taxCode!}', style: _base)],
    ),
    XlsxRow(
      3,
      cells: [XlsxCell.text('Địa chỉ: ${shop.address!}', style: _base)],
    ),
    XlsxRow(4, cells: [XlsxCell.empty(style: _base)]),
    XlsxRow(
      5,
      cells: _rowCells(
        startCol: 1,
        span: columns,
        text: 'SỔ CHI TIẾT DOANH THU BÁN HÀNG HÓA, DỊCH VỤ',
        style: _boldCenter,
      ),
    ),
    XlsxRow(
      6,
      cells: _rowCells(
        startCol: 1,
        span: columns,
        text: 'Địa điểm kinh doanh: ${shop.location!}',
        style: _center,
      ),
    ),
    XlsxRow(
      7,
      height: 24,
      cells: _rowCells(
        startCol: 1,
        span: columns,
        text: period,
        style: _period,
      ),
    ),
  ];
}

/// A row's cells for one piece of text merged across [span] columns
/// starting at [startCol] (1-based): `null` before it, the text cell, then
/// empty cells with the **same style**, so the border (if any) and
/// alignment carry across every covered cell of the merge.
List<XlsxCell?> _rowCells({
  required int startCol,
  required int span,
  required String text,
  required CellStyle style,
}) => [
  for (var c = 1; c < startCol; c++) null,
  XlsxCell.text(text, style: style),
  for (var c = 1; c < span; c++) XlsxCell.empty(style: style),
];

/// `Tổng tháng M` (RPT6), [monthNum] without a leading zero.
String _tongThang(int monthNum) => 'Tổng tháng $monthNum';

/// `DD/MM/YYYY` from a `YYYY-MM-DD` day (both already zero-padded).
String _formatDmy(String isoDay) =>
    '${isoDay.substring(8, 10)}/${isoDay.substring(5, 7)}/'
    '${isoDay.substring(0, 4)}';

int _dayOfMonth(String isoDay) => int.parse(isoDay.substring(8, 10));

int _monthNumber(String month) => int.parse(month.substring(5, 7));

String _year(String month) => month.substring(0, 4);
