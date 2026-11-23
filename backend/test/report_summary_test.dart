import 'dart:io';

import 'package:food_orders_backend/orders_report.dart';
import 'package:food_orders_backend/report_summary.dart';
import 'package:food_orders_backend/shop_settings.dart';
import 'package:test/test.dart';

import 'xlsx_test_reader.dart';

// Obviously fake test values; never real data.
Map<String, String?> _fakeEnv({Map<String, String?> overrides = const {}}) => {
  'SHOP_NAME': 'HỘ KINH DOANH QUÁN THỬ NGHIỆM',
  'SHOP_TAX_CODE': '0000000000-999',
  'SHOP_ADDRESS': '99 Đường Giả Định, Phường Thử, Quận Không Thật',
  'SHOP_LOCATION': '100 Đường Demo',
  'SHOP_REPRESENTATIVE': 'Nguyễn Văn Mẫu',
  'BANK_BIN': '000000',
  'BANK_ACCOUNT': '0000000000',
  'BANK_ACCOUNT_NAME': 'NGUYEN VAN MAU',
  'BANK_NAME': 'Ngân hàng Giả Định',
  ...overrides,
};

ShopSettings _fakeShop({Map<String, String?> overrides = const {}}) =>
    ShopSettings(_fakeEnv(overrides: overrides));

const _thin = {
  'left': 'thin',
  'right': 'thin',
  'top': 'thin',
  'bottom': 'thin',
};

/// Leap years included, same formula as `orders_report.dart`'s
/// `daysInMonth` (kept independent on purpose: this test file doesn't
/// import it).
int _daysInMonth(String month) {
  final year = int.parse(month.substring(0, 4));
  final monthNumber = int.parse(month.substring(5, 7));
  return DateTime(year, monthNumber + 1, 0).day;
}

ReportOrder _order({
  required String day,
  required String description,
  required num total,
  String method = 'cash',
}) => ReportOrder(
  day: day,
  description: description,
  total: total,
  method: method,
);

DayTotals _emptyDay(String month, int day) => DayTotals(
  day: '$month-${day.toString().padLeft(2, '0')}',
  cash: 0,
  transfer: 0,
  orders: const [],
);

DayTotals _dayWithOrders(String month, int day, List<ReportOrder> orders) {
  num cash = 0, transfer = 0;
  for (final o in orders) {
    if (o.method == 'bank_transfer') {
      transfer += o.total;
    } else {
      cash += o.total;
    }
  }
  return DayTotals(
    day: '$month-${day.toString().padLeft(2, '0')}',
    cash: cash,
    transfer: transfer,
    orders: orders,
  );
}

/// Every calendar day of [month], empty except for the days named in
/// [overrides] (1-based day of month).
List<DayTotals> _monthDays(
  String month, {
  Map<int, DayTotals> overrides = const {},
}) => [
  for (var day = 1; day <= _daysInMonth(month); day++)
    overrides[day] ?? _emptyDay(month, day),
];

ReadWorkbook _build({
  ShopSettings? shop,
  required String month,
  required List<DayTotals> days,
}) => ReadWorkbook.read(
  buildSummaryReport(shop: shop ?? _fakeShop(), month: month, days: days),
);

void main() {
  test('sheet names are exactly gộp then tách', () {
    final wb = _build(month: '2026-03', days: _monthDays('2026-03'));
    expect(wb.sheetNames, ['gộp', 'tách']);
  });

  group('layout for every day count (28, 29, 30, 31)', () {
    for (final (month, d) in [
      ('2027-02', 28),
      ('2028-02', 29),
      ('2026-04', 30),
      ('2026-03', 31),
    ]) {
      test('D=$d ($month)', () {
        expect(_daysInMonth(month), d, reason: 'test setup sanity check');
        final shop = _fakeShop();
        final wb = _build(month: month, days: _monthDays(month));
        final gop = wb.sheet('gộp');
        final tach = wb.sheet('tách');
        final monthNum = int.parse(month.substring(5, 7));
        final year = month.substring(0, 4);

        // --- gộp: columns.
        final gopCols = gop.columns;
        expect(gopCols[0].min, 1);
        expect(gopCols[0].max, 1);
        expect(gopCols[0].width, 28.33203125);
        expect(gopCols[1].min, 2);
        expect(gopCols[1].width, 79.5546875);
        expect(gopCols[2].min, 3);
        expect(gopCols[2].width, 54);
        expect(gopCols[3].min, 4);
        expect(gopCols[3].max, 16384);
        expect(gopCols[3].width, 8.88671875);
        for (final c in gopCols) {
          expect(c.style!.fontName, 'Calibri');
          expect(c.style!.fontSize, 18);
        }

        // --- gộp: title block, rows 1-4.
        expect(gop.cell('A1')!.text, shop.shopName);
        expect(gop.cell('A1')!.style.bold, isTrue);
        expect(gop.cell('A2')!.text, 'Mã số thuế: ${shop.taxCode}');
        expect(gop.cell('A3')!.text, 'Địa chỉ: ${shop.address}');
        expect(gop.cell('A4')!.type, 'empty');
        expect(gop.cell('A4')!.style.fontSize, 18);
        for (final ref in ['A1', 'A2', 'A3', 'A4']) {
          expect(gop.cell(ref)!.style.borders, isEmpty, reason: ref);
        }

        // --- gộp: rows 5-7.
        expect(
          gop.cell('A5')!.text,
          'SỔ CHI TIẾT DOANH THU BÁN HÀNG HÓA, DỊCH VỤ',
        );
        expect(gop.cell('A5')!.style.bold, isTrue);
        expect(gop.cell('A5')!.style.horizontal, 'center');
        expect(gop.cell('A6')!.text, 'Địa điểm kinh doanh: ${shop.location}');
        expect(gop.cell('A6')!.style.horizontal, 'center');
        expect(gop.cell('A7')!.text, 'Kỳ báo cáo: Tháng $monthNum năm $year');
        expect(gop.cell('A7')!.style.horizontal, 'center');
        expect(gop.merges, containsAll(['A5:B5', 'A6:B6', 'A7:B7']));
        expect(gop.rows[7]!.height, 24);
        expect(gop.rows[7]!.customHeight, isFalse);
        // RPT8 exception: the bottom edge under row 7's period line.
        expect(gop.cell('A7')!.style.borders, {'bottom': 'thin'});
        expect(gop.cell('B7')!.style.borders, {'bottom': 'thin'});
        // Nothing else in the title block has a border.
        for (final ref in ['A5', 'B5', 'A6', 'B6']) {
          expect(gop.cell(ref)!.style.borders, isEmpty, reason: ref);
        }

        // --- gộp: header row 8.
        expect(gop.cell('A8')!.text, 'Ngày, tháng, năm');
        expect(gop.cell('A8')!.style.bold, isTrue);
        expect(gop.cell('A8')!.style.wrap, isTrue);
        expect(gop.cell('B8')!.text, 'Giao dịch');
        expect(gop.cell('B8')!.style.bold, isTrue);
        expect(gop.cell('B8')!.style.horizontal, 'center');
        expect(gop.cell('C8')!.text, 'Số tiền');
        expect(gop.cell('C8')!.style.bold, isTrue);
        expect(gop.cell('C8')!.style.horizontal, 'center');
        for (final ref in ['A8', 'B8', 'C8']) {
          expect(gop.cell(ref)!.style.borders, _thin, reason: ref);
        }

        // --- gộp: day rows 9..8+D.
        for (var day = 1; day <= d; day++) {
          final r = 8 + day;
          final dd = day.toString().padLeft(2, '0');
          final mm = monthNum.toString().padLeft(2, '0');
          expect(gop.cell('A$r')!.text, 'Ngày $dd/$mm/$year', reason: 'A$r');
          expect(
            gop.cell('B$r')!.text,
            'Bán hàng cho khách không biết tên, không lấy hóa đơn',
            reason: 'B$r',
          );
          expect(gop.cell('C$r')!.number, 0, reason: 'C$r');
          expect(gop.cell('C$r')!.style.thousands, isTrue, reason: 'C$r');
          for (final col in ['A', 'B', 'C']) {
            expect(gop.cell('$col$r')!.style.borders, _thin, reason: '$col$r');
          }
        }

        // --- gộp: total row.
        final gopTotalRow = 9 + d;
        expect(gop.rows[gopTotalRow]!.height, 25.8);
        expect(gop.rows[gopTotalRow]!.customHeight, isFalse);
        expect(gop.cell('A$gopTotalRow')!.type, 'empty');
        expect(gop.cell('A$gopTotalRow')!.style.borders, _thin);
        expect(gop.cell('B$gopTotalRow')!.text, 'Tổng cộng');
        expect(gop.cell('B$gopTotalRow')!.style.bold, isTrue);
        expect(gop.cell('B$gopTotalRow')!.style.fontSize, 20);
        expect(gop.cell('B$gopTotalRow')!.style.horizontal, 'center');
        final gopTotal = gop.cell('C$gopTotalRow')!;
        expect(gopTotal.type, 'formula');
        expect(gopTotal.formula, 'SUM(C9:C${8 + d})');
        expect(gopTotal.number, 0);
        expect(gopTotal.style.bold, isTrue);
        expect(gopTotal.style.fontSize, 20);
        expect(gopTotal.style.thousands, isTrue);
        for (final col in ['A', 'B', 'C']) {
          expect(
            gop.cell('$col$gopTotalRow')!.style.borders,
            _thin,
            reason: col,
          );
        }

        // --- gộp: footer date row.
        final gopDateRow = 10 + d;
        expect(
          gop.cell('C$gopDateRow')!.text,
          'Ngày $d tháng $monthNum năm $year',
        );
        expect(gop.cell('C$gopDateRow')!.style.italic, isTrue);
        expect(gop.cell('C$gopDateRow')!.style.horizontal, 'center');
        // RPT8 exception: the top edge of the footer date cell.
        for (final col in ['C', 'D', 'E']) {
          expect(gop.cell('$col$gopDateRow')!.style.borders, {
            'top': 'thin',
          }, reason: col);
        }
        expect(gop.merges, contains('C$gopDateRow:E$gopDateRow'));

        // --- gộp: signature block.
        final gopTitleRow = 11 + d;
        expect(gop.cell('C$gopTitleRow')!.text, 'NGƯỜI ĐẠI DIỆN HỘ KINH DOANH');
        expect(gop.cell('C$gopTitleRow')!.style.horizontal, 'center');
        expect(gop.cell('C$gopTitleRow')!.style.borders, isEmpty);
        expect(gop.rows[gopTitleRow]!.height, 25.8);
        expect(gop.rows[gopTitleRow]!.customHeight, isTrue);
        expect(gop.merges, contains('C$gopTitleRow:E$gopTitleRow'));

        for (var r = 12 + d; r <= 15 + d; r++) {
          expect(gop.cell('A$r')!.type, 'empty', reason: 'A$r');
          expect(gop.cell('A$r')!.style.borders, isEmpty, reason: 'A$r');
          expect(gop.cell('A$r')!.style.fontSize, 18, reason: 'A$r');
        }

        final gopNameRow = 16 + d;
        expect(gop.cell('C$gopNameRow')!.text, shop.representative);
        expect(gop.cell('C$gopNameRow')!.style.bold, isTrue);
        expect(gop.cell('C$gopNameRow')!.style.fontName, 'Times New Roman');
        expect(gop.cell('C$gopNameRow')!.style.fontSize, 16);
        expect(gop.cell('C$gopNameRow')!.style.horizontal, 'center');
        expect(gop.cell('C$gopNameRow')!.style.borders, isEmpty);
        expect(gop.merges, contains('C$gopNameRow:E$gopNameRow'));

        // Nothing beyond the name row.
        expect(gop.cell('A${gopNameRow + 1}'), isNull);

        // --- tách: columns.
        final tachCols = tach.columns;
        expect(tachCols[0].width, 28.33203125);
        expect(tachCols[1].width, 79.5546875);
        expect(tachCols[2].width, 21.88671875);
        expect(tachCols[3].width, 21.88671875);
        expect(tachCols[4].width, 21.88671875);
        expect(tachCols[5].min, 6);
        expect(tachCols[5].max, 16384);
        expect(tachCols[5].width, 8.88671875);
        for (final c in tachCols) {
          expect(c.style!.fontName, 'Calibri');
          expect(c.style!.fontSize, 18);
        }

        // --- tách: rows 1-7, same text, wider merges.
        expect(tach.cell('A1')!.text, shop.shopName);
        expect(
          tach.cell('A5')!.text,
          'SỔ CHI TIẾT DOANH THU BÁN HÀNG HÓA, DỊCH VỤ',
        );
        expect(tach.cell('A7')!.text, 'Kỳ báo cáo: Tháng $monthNum năm $year');
        expect(tach.merges, containsAll(['A5:C5', 'A6:C6', 'A7:C7']));
        expect(tach.cell('A7')!.style.borders, {'bottom': 'thin'});
        expect(tach.cell('B7')!.style.borders, {'bottom': 'thin'});
        expect(tach.cell('C7')!.style.borders, {'bottom': 'thin'});

        // --- tách: header rows 8-9.
        expect(tach.cell('A8')!.text, 'Ngày, tháng, năm');
        expect(tach.cell('A8')!.style.wrap, isTrue);
        expect(tach.cell('B8')!.text, 'Nội dung');
        expect(tach.cell('B8')!.style.horizontal, 'center');
        expect(tach.cell('C8')!.text, 'Số tiền');
        expect(tach.cell('C8')!.style.horizontal, 'center');
        expect(tach.merges, contains('C8:E8'));
        for (final col in ['A', 'B', 'C', 'D', 'E']) {
          expect(tach.cell('${col}8')!.style.borders, _thin, reason: col);
        }

        expect(tach.rows[9]!.height, 24);
        expect(tach.rows[9]!.customHeight, isFalse);
        expect(tach.cell('A9')!.type, 'empty');
        expect(tach.cell('B9')!.type, 'empty');
        expect(tach.cell('C9')!.text, 'Chuyển khoản');
        expect(tach.cell('C9')!.style.bold, isTrue);
        // RPT8/"C9 centred": deliberate, unlike the sample.
        expect(tach.cell('C9')!.style.horizontal, 'center');
        expect(tach.cell('D9')!.text, 'Tiền mặt');
        expect(tach.cell('D9')!.style.horizontal, 'center');
        expect(tach.cell('E9')!.text, 'Cộng');
        expect(tach.cell('E9')!.style.horizontal, 'center');
        for (final col in ['A', 'B', 'C', 'D', 'E']) {
          expect(tach.cell('${col}9')!.style.borders, _thin, reason: col);
        }

        // --- tách: day rows 10..9+D.
        for (var day = 1; day <= d; day++) {
          final r = 9 + day;
          final dd = day.toString().padLeft(2, '0');
          final mm = monthNum.toString().padLeft(2, '0');
          expect(tach.cell('A$r')!.text, 'Ngày $dd/$mm/$year', reason: 'A$r');
          expect(
            tach.cell('B$r')!.text,
            'Bán hàng cho khách không biết tên, không lấy hóa đơn',
            reason: 'B$r',
          );
          expect(tach.cell('C$r')!.number, 0, reason: 'C$r');
          expect(tach.cell('D$r')!.number, 0, reason: 'D$r');
          final e = tach.cell('E$r')!;
          expect(e.type, 'formula', reason: 'E$r');
          expect(e.formula, 'D$r+C$r', reason: 'E$r');
          expect(e.number, 0, reason: 'E$r');
          for (final col in ['A', 'B', 'C', 'D', 'E']) {
            expect(tach.cell('$col$r')!.style.borders, _thin, reason: '$col$r');
            expect(
              tach.cell('$col$r')!.style.thousands,
              col == 'C' || col == 'D' || col == 'E',
              reason: '$col$r',
            );
          }
        }

        // --- tách: total row.
        final tachTotalRow = 10 + d;
        expect(tach.rows[tachTotalRow]!.height, 25.8);
        expect(tach.rows[tachTotalRow]!.customHeight, isFalse);
        expect(tach.cell('A$tachTotalRow')!.text, 'Tổng tháng $monthNum');
        expect(tach.cell('A$tachTotalRow')!.style.bold, isTrue);
        expect(tach.cell('A$tachTotalRow')!.style.fontSize, 20);
        // Only the gộp label is centred; tách's is not.
        expect(tach.cell('A$tachTotalRow')!.style.horizontal, isNull);
        expect(tach.cell('B$tachTotalRow')!.type, 'empty');
        final c = tach.cell('C$tachTotalRow')!;
        final dd = tach.cell('D$tachTotalRow')!;
        final e = tach.cell('E$tachTotalRow')!;
        expect(c.formula, 'SUM(C10:C${9 + d})');
        expect(c.number, 0);
        expect(dd.formula, 'SUM(D10:D${9 + d})');
        expect(dd.number, 0);
        expect(e.formula, 'SUM(E10:E${9 + d})');
        expect(e.number, 0);
        for (final cell in [c, dd, e]) {
          expect(cell.style.bold, isTrue);
          expect(cell.style.fontSize, 20);
          expect(cell.style.thousands, isTrue);
        }
        for (final col in ['A', 'B', 'C', 'D', 'E']) {
          expect(
            tach.cell('$col$tachTotalRow')!.style.borders,
            _thin,
            reason: col,
          );
        }

        // --- tách: footer date row.
        final tachDateRow = 11 + d;
        expect(
          tach.cell('C$tachDateRow')!.text,
          'Ngày $d tháng $monthNum năm $year',
        );
        expect(tach.cell('C$tachDateRow')!.style.italic, isTrue);
        expect(tach.cell('C$tachDateRow')!.style.horizontal, 'center');
        for (final col in ['C', 'D', 'E']) {
          expect(tach.cell('$col$tachDateRow')!.style.borders, {
            'top': 'thin',
          }, reason: col);
        }
        expect(tach.merges, contains('C$tachDateRow:E$tachDateRow'));

        // --- tách: signature block.
        final tachTitleRow = 12 + d;
        expect(
          tach.cell('C$tachTitleRow')!.text,
          'NGƯỜI ĐẠI DIỆN HỘ KINH DOANH',
        );
        expect(tach.cell('C$tachTitleRow')!.style.borders, isEmpty);
        expect(tach.rows[tachTitleRow]!.height, 25.8);
        expect(tach.rows[tachTitleRow]!.customHeight, isTrue);
        expect(tach.merges, contains('C$tachTitleRow:E$tachTitleRow'));

        for (var r = 13 + d; r <= 16 + d; r++) {
          expect(tach.cell('A$r')!.type, 'empty', reason: 'A$r');
          expect(tach.cell('A$r')!.style.borders, isEmpty, reason: 'A$r');
          expect(tach.cell('A$r')!.style.fontSize, 18, reason: 'A$r');
        }

        final tachNameRow = 17 + d;
        expect(tach.cell('C$tachNameRow')!.text, shop.representative);
        expect(tach.cell('C$tachNameRow')!.style.bold, isTrue);
        expect(tach.cell('C$tachNameRow')!.style.fontName, 'Times New Roman');
        expect(tach.cell('C$tachNameRow')!.style.fontSize, 16);
        expect(tach.cell('C$tachNameRow')!.style.borders, isEmpty);
        expect(tach.merges, contains('C$tachNameRow:E$tachNameRow'));
        expect(tach.cell('A${tachNameRow + 1}'), isNull);
      });
    }
  });

  group('amounts', () {
    test('three orders on one day (2 cash, 1 transfer)', () {
      final month = '2026-06';
      final day = _dayWithOrders(month, 1, [
        _order(day: '2026-06-01', description: 'Xôi ruốc', total: 20000),
        _order(day: '2026-06-01', description: 'Trà đá', total: 10000),
        _order(
          day: '2026-06-01',
          description: '2 Trà đá',
          total: 16000,
          method: 'bank_transfer',
        ),
      ]);
      final days = _monthDays(month, overrides: {1: day});
      final wb = _build(month: month, days: days);
      final gop = wb.sheet('gộp');
      final tach = wb.sheet('tách');

      // gộp row 9 = day 1: cash + transfer together.
      expect(gop.cell('C9')!.number, 46000);

      // tách row 10 = day 1: C transfer, D cash, E = D+C.
      expect(tach.cell('C10')!.number, 16000);
      expect(tach.cell('D10')!.number, 30000);
      expect(tach.cell('E10')!.number, 46000);

      // gộp C equals tách E for the same day.
      expect(gop.cell('C9')!.number, tach.cell('E10')!.number);
    });

    test('an empty day shows 0 (not blank) and the standard description', () {
      final month = '2026-06';
      final days = _monthDays(month);
      final wb = _build(month: month, days: days);
      final gop = wb.sheet('gộp');
      final tach = wb.sheet('tách');

      expect(gop.cell('C9')!.type, 'number');
      expect(gop.cell('C9')!.number, 0);
      expect(
        gop.cell('B9')!.text,
        'Bán hàng cho khách không biết tên, không lấy hóa đơn',
      );
      expect(tach.cell('C10')!.number, 0);
      expect(tach.cell('D10')!.number, 0);
      expect(tach.cell('E10')!.number, 0);
    });

    test('gộp C equals tách E for every day of the month', () {
      final month = '2026-06';
      final days = _monthDays(
        month,
        overrides: {
          1: _dayWithOrders(month, 1, [
            _order(day: '2026-06-01', description: 'A', total: 5000),
          ]),
          15: _dayWithOrders(month, 15, [
            _order(
              day: '2026-06-15',
              description: 'B',
              total: 7000,
              method: 'bank_transfer',
            ),
          ]),
          30: _dayWithOrders(month, 30, [
            _order(day: '2026-06-30', description: 'C', total: 1000),
            _order(
              day: '2026-06-30',
              description: 'D',
              total: 2000,
              method: 'bank_transfer',
            ),
          ]),
        },
      );
      final wb = _build(month: month, days: days);
      final gop = wb.sheet('gộp');
      final tach = wb.sheet('tách');

      for (var day = 1; day <= days.length; day++) {
        final gopRow = 8 + day;
        final tachRow = 9 + day;
        expect(
          gop.cell('C$gopRow')!.number,
          tach.cell('E$tachRow')!.number,
          reason: 'day $day',
        );
      }

      // The grand-total cells' cached SUM values must reflect the actual
      // nonzero amounts above, not just sum a month of zeros to zero.
      // Cash: 5000 (day 1) + 1000 (day 30) = 6000.
      // Transfer: 7000 (day 15) + 2000 (day 30) = 9000.
      final gopTotalRow = 9 + days.length;
      final tachTotalRow = 10 + days.length;
      expect(gop.cell('C$gopTotalRow')!.number, 15000);
      expect(tach.cell('C$tachTotalRow')!.number, 9000);
      expect(tach.cell('D$tachTotalRow')!.number, 6000);
      expect(tach.cell('E$tachTotalRow')!.number, 15000);
    });

    test('an order resolved as cash (no stored method) lands in the cash '
        'column — this module only draws what it is handed, PAY6 already '
        'resolved it one layer up', () {
      final month = '2026-06';
      final day = _dayWithOrders(month, 1, [
        _order(day: '2026-06-01', description: 'Trà đá', total: 10000),
      ]);
      final days = _monthDays(month, overrides: {1: day});
      final wb = _build(month: month, days: days);
      final tach = wb.sheet('tách');
      expect(tach.cell('D10')!.number, 10000);
      expect(tach.cell('C10')!.number, 0);
    });
  });

  group('total labels', () {
    test('gộp keeps "Tổng cộng"', () {
      final wb = _build(month: '2026-03', days: _monthDays('2026-03'));
      expect(wb.sheet('gộp').cell('C40')!.formula, 'SUM(C9:C39)');
      expect(wb.sheet('gộp').cell('B40')!.text, 'Tổng cộng');
    });

    test('tách total label is "Tổng tháng 3" for March', () {
      final wb = _build(month: '2026-03', days: _monthDays('2026-03'));
      expect(wb.sheet('tách').cell('A41')!.text, 'Tổng tháng 3');
    });

    test('tách total label is "Tổng tháng 11" for November', () {
      final wb = _build(month: '2026-11', days: _monthDays('2026-11'));
      expect(wb.sheet('tách').cell('A40')!.text, 'Tổng tháng 11');
    });
  });

  group('header text and typo fixes', () {
    test('A1 is exactly the configured shop name, no prefix added', () {
      final shop = _fakeShop(overrides: {'SHOP_NAME': 'HỘ KINH DOANH QUÁN LẠ'});
      final wb = _build(
        shop: shop,
        month: '2026-03',
        days: _monthDays('2026-03'),
      );
      expect(wb.sheet('gộp').cell('A1')!.text, 'HỘ KINH DOANH QUÁN LẠ');
    });

    test('no sample typo anywhere on either sheet', () {
      final wb = _build(month: '2026-03', days: _monthDays('2026-03'));
      for (final sheet in [wb.sheet('gộp'), wb.sheet('tách')]) {
        final allText = [
          for (final c in sheet.cells.values)
            if (c.text != null) c.text!,
        ].join('|');
        expect(allText, isNot(contains('KIMH')));
        expect(allText, isNot(contains('SỎ CHI')));
        expect(allText, isNot(contains('TIÊT')));
        expect(allText, isNot(contains('măt')));
        expect(allText, contains('HỘ KINH DOANH'));
        expect(allText, contains('SỔ CHI TIẾT'));
      }
      // "tách" is the only sheet with "Tiền mặt" on it.
      final tachText = [
        for (final c in wb.sheet('tách').cells.values)
          if (c.text != null) c.text!,
      ].join('|');
      expect(tachText, contains('Tiền mặt'));
    });

    test('dates are zero-padded everywhere, e.g. "Ngày 08/03/2026"', () {
      final wb = _build(month: '2026-03', days: _monthDays('2026-03'));
      expect(wb.sheet('gộp').cell('A16')!.text, 'Ngày 08/03/2026');
      expect(wb.sheet('tách').cell('A17')!.text, 'Ngày 08/03/2026');
    });
  });

  group('escaping', () {
    test('shop text with "&", "<" and Vietnamese letters survives intact', () {
      final shop = _fakeShop(
        overrides: {
          'SHOP_NAME': 'HỘ KINH DOANH A & B <Thử>',
          'SHOP_ADDRESS': 'Số 1 & 2, Đường <Thử Nghiệm>',
        },
      );
      final wb = _build(
        shop: shop,
        month: '2026-03',
        days: _monthDays('2026-03'),
      );
      expect(wb.sheet('gộp').cell('A1')!.text, 'HỘ KINH DOANH A & B <Thử>');
      expect(
        wb.sheet('gộp').cell('A3')!.text,
        'Địa chỉ: Số 1 & 2, Đường <Thử Nghiệm>',
      );
    });
  });

  group('validation', () {
    test('an invalid month throws ArgumentError', () {
      expect(
        () => buildSummaryReport(
          shop: _fakeShop(),
          month: '2026-13',
          days: _monthDays('2026-01'),
        ),
        throwsArgumentError,
      );
      expect(
        () => buildSummaryReport(
          shop: _fakeShop(),
          month: '2026-3',
          days: _monthDays('2026-03'),
        ),
        throwsArgumentError,
      );
    });

    test('an empty days list throws ArgumentError', () {
      expect(
        () => buildSummaryReport(
          shop: _fakeShop(),
          month: '2026-03',
          days: const [],
        ),
        throwsArgumentError,
      );
    });

    test('shop.reportEnabled == false (a missing SHOP_* value) throws '
        'ArgumentError instead of a null-check TypeError', () {
      final incompleteShop = _fakeShop(overrides: {'SHOP_NAME': null});
      expect(incompleteShop.reportEnabled, isFalse);
      expect(
        () => buildSummaryReport(
          shop: incompleteShop,
          month: '2026-03',
          days: _monthDays('2026-03'),
        ),
        throwsArgumentError,
      );
    });
  });

  test('no file access in the module', () {
    final source = File('lib/report_summary.dart').readAsStringSync();
    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(contains('import "dart:io"')));
  });
}
