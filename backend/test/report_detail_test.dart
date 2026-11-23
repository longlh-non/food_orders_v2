import 'dart:io';

import 'package:food_orders_backend/orders_report.dart';
import 'package:food_orders_backend/report_detail.dart';
import 'package:test/test.dart';

import 'xlsx_test_reader.dart';

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

DayTotals _day(String day, List<ReportOrder> orders) {
  num cash = 0, transfer = 0;
  for (final o in orders) {
    if (o.method == 'bank_transfer') {
      transfer += o.total;
    } else {
      cash += o.total;
    }
  }
  return DayTotals(day: day, cash: cash, transfer: transfer, orders: orders);
}

ReadWorkbook _build({required String month, required List<DayTotals> days}) =>
    ReadWorkbook.read(buildDetailReport(month: month, days: days));

void main() {
  group('layout, shared by every report', () {
    test('sheet name, columns, row 1 height', () {
      final sheet = _build(month: '2026-11', days: const []).sheet('Sheet1');
      final cols = sheet.columns;
      expect(cols[0].min, 1);
      expect(cols[0].max, 1);
      expect(cols[0].width, 26.109375);
      expect(cols[1].min, 2);
      expect(cols[1].width, 39.77734375);
      expect(cols[2].min, 3);
      expect(cols[2].width, 31.5546875);
      expect(cols[2].style!.thousands, isTrue);
      expect(cols[3].min, 4);
      expect(cols[3].width, 28.6640625);
      expect(cols[3].style!.thousands, isTrue);
      expect(cols[4].min, 5);
      expect(cols[4].max, 16384);
      expect(cols[4].width, 8.88671875);
      expect(cols[4].style!.thousands, isFalse);
      for (final c in cols) {
        expect(c.style!.fontName, 'Calibri');
        expect(c.style!.fontSize, 18);
      }
      expect(sheet.rows[1]!.height, 24);
      expect(sheet.rows[1]!.customHeight, isFalse);
    });

    test('month title: no leading zero on the month', () {
      expect(
        _build(
          month: '2026-11',
          days: const [],
        ).sheet('Sheet1').cell('A1')!.text,
        'Chi tiết tháng 11/2026',
      );
      expect(
        _build(
          month: '2026-06',
          days: const [],
        ).sheet('Sheet1').cell('A1')!.text,
        'Chi tiết tháng 6/2026',
      );
      expect(
        _build(
          month: '2026-11',
          days: const [],
        ).sheet('Sheet1').cell('A1')!.style.bold,
        isTrue,
      );
    });

    test('the three header merges', () {
      expect(_build(month: '2026-11', days: const []).sheet('Sheet1').merges, [
        'A2:A3',
        'B2:B3',
        'C2:D2',
      ]);
    });

    test('header texts and styles', () {
      final sheet = _build(month: '2026-11', days: const []).sheet('Sheet1');

      final a2 = sheet.cell('A2')!;
      expect(a2.text, 'Ngày tháng năm');
      expect(a2.style.bold, isTrue);
      expect(a2.style.horizontal, 'center');
      expect(a2.style.vertical, 'center');
      expect(a2.style.wrap, isTrue);

      final b2 = sheet.cell('B2')!;
      expect(b2.text, 'Giao dịch');
      expect(b2.style.bold, isTrue);
      expect(b2.style.horizontal, 'center');
      expect(b2.style.vertical, 'center');
      expect(b2.style.wrap, isTrue);

      final c2 = sheet.cell('C2')!;
      expect(c2.text, 'Số tiền');
      expect(c2.style.bold, isTrue);
      expect(c2.style.horizontal, 'center');

      final c3 = sheet.cell('C3')!;
      expect(c3.text, 'Tiền mặt');
      expect(c3.style.bold, isTrue);
      expect(c3.style.horizontal, 'center');

      final d3 = sheet.cell('D3')!;
      expect(d3.text, 'Chuyển khoản');
      expect(d3.style.bold, isTrue);
      expect(d3.style.horizontal, 'center');

      // Covered merge cells still carry the table border.
      for (final ref in ['A3', 'B3', 'D2']) {
        expect(sheet.cell(ref)!.style.borders, {
          'left': 'thin',
          'right': 'thin',
          'top': 'thin',
          'bottom': 'thin',
        }, reason: ref);
      }
    });

    test('row 4 is an empty bordered spacer across A:D', () {
      final sheet = _build(month: '2026-11', days: const []).sheet('Sheet1');
      for (final ref in ['A4', 'B4', 'C4', 'D4']) {
        final cell = sheet.cell(ref)!;
        expect(cell.type, 'empty', reason: ref);
        expect(cell.style.borders, {
          'left': 'thin',
          'right': 'thin',
          'top': 'thin',
          'bottom': 'thin',
        }, reason: ref);
        expect(cell.style.fontSize, 18, reason: ref);
      }
    });

    test('an empty month gives rows 1-4 only; no row 5', () {
      final sheet = _build(month: '2026-11', days: const []).sheet('Sheet1');
      expect(sheet.rows.keys.toSet(), {1, 2, 3, 4});
      expect(sheet.rows[1]!.height, 24);
      expect(sheet.rows[2]!.height, isNull);
      expect(sheet.rows[3]!.height, isNull);
      expect(sheet.rows[4]!.height, isNull);
      for (final ref in ['A4', 'B4', 'C4', 'D4']) {
        expect(sheet.cell(ref), isNotNull, reason: ref);
      }
      expect(sheet.cell('A5'), isNull);
    });

    test('no sample typo anywhere on the sheet', () {
      final sheet = _build(month: '2026-11', days: const []).sheet('Sheet1');
      final allText = [
        for (final c in sheet.cells.values)
          if (c.text != null) c.text!,
      ].join('|');
      expect(allText, isNot(contains('tiêt')));
      expect(allText, isNot(contains('măt')));
      expect(allText, contains('Chi tiết'));
      expect(allText, contains('Tiền mặt'));
    });
  });

  group('day blocks', () {
    test('two days (3 and 2 orders): headers, rows, formulas, next header '
        'immediately after the sum row', () {
      final day1 = _day('2026-06-01', [
        _order(day: '2026-06-01', description: 'Xôi ruốc', total: 20000),
        _order(
          day: '2026-06-01',
          description: '2 Xôi thịt (Thêm chả), Trà đá',
          total: 66000,
        ),
        _order(
          day: '2026-06-01',
          description: 'Trà đá',
          total: 15000,
          method: 'bank_transfer',
        ),
      ]);
      final day2 = _day('2026-06-03', [
        _order(day: '2026-06-03', description: 'Xôi ruốc', total: 12000),
        _order(day: '2026-06-03', description: 'Trà đá', total: 8000),
      ]);

      final sheet = _build(
        month: '2026-06',
        days: [day1, day2],
      ).sheet('Sheet1');

      // Day 1: header row 5, orders 6-8, sum row 9.
      expect(sheet.cell('A5')!.text, 'Ngày 01/06/2026');
      expect(sheet.cell('A5')!.style.bold, isTrue);
      expect(sheet.cell('B5'), isNotNull);
      expect(sheet.cell('B5')!.type, 'empty');

      expect(sheet.cell('B6')!.text, 'Xôi ruốc');
      expect(sheet.cell('B6')!.style.wrap, isTrue);
      expect(sheet.cell('C6')!.number, 20000);
      expect(sheet.cell('D6')!.type, 'empty');
      expect(sheet.cell('A6')!.type, 'empty');

      expect(sheet.cell('B7')!.text, '2 Xôi thịt (Thêm chả), Trà đá');
      expect(sheet.cell('C7')!.number, 66000);
      expect(sheet.cell('D7')!.type, 'empty');

      expect(sheet.cell('B8')!.text, 'Trà đá');
      expect(sheet.cell('D8')!.number, 15000);
      expect(sheet.cell('C8')!.type, 'empty');

      expect(sheet.cell('B9')!.text, 'Cộng ngày 01/06/2026');
      expect(sheet.cell('B9')!.style.bold, isTrue);
      expect(sheet.cell('C9')!.type, 'formula');
      expect(sheet.cell('C9')!.formula, 'SUM(C6:C8)');
      expect(sheet.cell('C9')!.number, 86000);
      expect(sheet.cell('C9')!.style.bold, isTrue);
      expect(sheet.cell('C9')!.style.thousands, isTrue);
      expect(sheet.cell('D9')!.formula, 'SUM(D6:D8)');
      expect(sheet.cell('D9')!.number, 15000);

      // Day 2 starts immediately on row 10 (no blank row after row 9).
      expect(sheet.cell('A10')!.text, 'Ngày 03/06/2026');
      expect(sheet.cell('B11')!.text, 'Xôi ruốc');
      expect(sheet.cell('C11')!.number, 12000);
      expect(sheet.cell('B12')!.text, 'Trà đá');
      expect(sheet.cell('C12')!.number, 8000);

      // Sum row 13, all cash: D's sum is 0 (RPT: empty money cells show 0).
      expect(sheet.cell('B13')!.text, 'Cộng ngày 03/06/2026');
      expect(sheet.cell('C13')!.formula, 'SUM(C11:C12)');
      expect(sheet.cell('C13')!.number, 20000);
      expect(sheet.cell('D13')!.formula, 'SUM(D11:D12)');
      expect(sheet.cell('D13')!.number, 0);
      expect(sheet.cell('D13')!.style.bold, isTrue);
      expect(sheet.cell('D13')!.style.thousands, isTrue);

      // No block anywhere for the skipped day, 2 June.
      final allText = [
        for (final c in sheet.cells.values)
          if (c.text != null) c.text!,
      ];
      expect(allText, isNot(contains('Ngày 02/06/2026')));
      expect(allText, isNot(contains('Cộng ngày 02/06/2026')));

      // Nothing after the last sum row.
      expect(sheet.cell('A14'), isNull);
    });

    test('borders on every table cell, rows 2 to the last, columns A-D', () {
      final day = _day('2026-06-01', [
        _order(day: '2026-06-01', description: 'Xôi ruốc', total: 20000),
      ]);
      final sheet = _build(month: '2026-06', days: [day]).sheet('Sheet1');
      const thin = {
        'left': 'thin',
        'right': 'thin',
        'top': 'thin',
        'bottom': 'thin',
      };
      for (var r = 2; r <= 7; r++) {
        for (final col in ['A', 'B', 'C', 'D']) {
          expect(sheet.cell('$col$r')!.style.borders, thin, reason: '$col$r');
        }
      }
      // Row 1 (the title) has no border requirement.
      expect(sheet.cell('A1')!.style.borders, isEmpty);
    });

    test('a description with "=1+1" stays a string cell', () {
      final day = _day('2026-06-01', [
        _order(day: '2026-06-01', description: '=1+1', total: 1000),
      ]);
      final sheet = _build(month: '2026-06', days: [day]).sheet('Sheet1');
      expect(sheet.cell('B6')!.type, 'text');
      expect(sheet.cell('B6')!.text, '=1+1');
      expect(sheet.cell('B6')!.formula, isNull);
    });

    test('"&", "<" and Vietnamese letters survive in a description', () {
      const description = 'Phở <gà> & chả, Trứng ngải cứu';
      final day = _day('2026-06-01', [
        _order(day: '2026-06-01', description: description, total: 1000),
      ]);
      final sheet = _build(month: '2026-06', days: [day]).sheet('Sheet1');
      expect(sheet.cell('B6')!.text, description);
    });

    test('a "cash" order lands in C (PAY6: no-method orders already resolve '
        'to cash by the time this module sees them)', () {
      final day = _day('2026-06-01', [
        _order(day: '2026-06-01', description: 'Trà đá', total: 10000),
      ]);
      final sheet = _build(month: '2026-06', days: [day]).sheet('Sheet1');
      expect(sheet.cell('C6')!.number, 10000);
      expect(sheet.cell('D6')!.type, 'empty');
    });

    test('a non-whole total is written as it is', () {
      final day = _day('2026-06-01', [
        _order(day: '2026-06-01', description: 'Old USD order', total: 9.5),
      ]);
      final sheet = _build(month: '2026-06', days: [day]).sheet('Sheet1');
      expect(sheet.cell('C6')!.number, 9.5);
    });
  });

  group('validation', () {
    test('an invalid month throws ArgumentError', () {
      expect(
        () => buildDetailReport(month: '2026-13', days: const []),
        throwsArgumentError,
      );
      expect(
        () => buildDetailReport(month: '2026-6', days: const []),
        throwsArgumentError,
      );
    });
  });

  test('no file access in the module', () {
    final source = File('lib/report_detail.dart').readAsStringSync();
    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(contains('import "dart:io"')));
  });
}
