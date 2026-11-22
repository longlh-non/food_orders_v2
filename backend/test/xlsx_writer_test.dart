import 'package:food_orders_backend/xlsx_writer.dart';
import 'package:test/test.dart';

import 'xlsx_test_reader.dart';

ReadWorkbook roundTrip(List<XlsxSheet> sheets) =>
    ReadWorkbook.read(XlsxWorkbook(sheets).toBytes());

ReadCell onlyCell(XlsxCell cell) => roundTrip([
  XlsxSheet(
    'S',
    rows: [
      XlsxRow(1, cells: [cell]),
    ],
  ),
]).sheet('S').cell('A1')!;

void main() {
  group('package', () {
    test('has exactly the listed parts, all well-formed', () {
      final wb = roundTrip([XlsxSheet('gộp'), XlsxSheet('tách')]);
      expect(wb.partNames, [
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/sharedStrings.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
      ]);
      expect(wb.sheetNames, ['gộp', 'tách']);
      expect(wb.fullCalcOnLoad, isTrue);
    });

    test('content types and relationships point at real parts', () {
      final wb = roundTrip([XlsxSheet('A'), XlsxSheet('B')]);
      for (final target in wb.relationshipTargets) {
        expect(wb.partNames, contains(target));
      }
      for (final part in wb.contentTypeOverrides) {
        expect(wb.partNames, contains(part.substring(1)));
      }
      // Every part except the two defaults-covered rels/content types.
      for (final part in wb.partNames.where(
        (n) => n.startsWith('xl/') && !n.endsWith('.rels'),
      )) {
        expect(wb.contentTypeOverrides, contains('/$part'));
      }
    });
  });

  group('cells', () {
    test('text, number, formula with cached value, empty styled', () {
      const style = CellStyle(bold: true);
      final sheet = roundTrip([
        XlsxSheet(
          'S',
          rows: const [
            XlsxRow(
              2,
              cells: [
                XlsxCell.text('Xôi ruốc'),
                XlsxCell.number(25000),
                XlsxCell.formula('SUM(B2:B2)', 25000),
                null,
                XlsxCell.empty(style: style),
              ],
            ),
          ],
        ),
      ]).sheet('S');
      expect(sheet.cell('A2')!.type, 'text');
      expect(sheet.cell('A2')!.text, 'Xôi ruốc');
      expect(sheet.cell('B2')!.type, 'number');
      expect(sheet.cell('B2')!.number, 25000);
      expect(sheet.cell('C2')!.type, 'formula');
      expect(sheet.cell('C2')!.formula, 'SUM(B2:B2)');
      expect(sheet.cell('C2')!.number, 25000);
      expect(sheet.cell('D2'), isNull);
      expect(sheet.cell('E2')!.type, 'empty');
      expect(sheet.cell('E2')!.style.bold, isTrue);
    });

    test('a leading = on a formula is dropped; decimals are kept', () {
      final c = onlyCell(const XlsxCell.formula('=1+1', 2.5));
      expect(c.formula, '1+1');
      expect(c.number, 2.5);
    });

    test('merges, column widths and default styles, row heights', () {
      const col = CellStyle(fontSize: 18);
      final sheet = roundTrip([
        XlsxSheet(
          'S',
          columns: const [
            XlsxColumn(1, 1, 28.33203125, style: col),
            XlsxColumn(2, 4, 21.88671875),
          ],
          rows: const [
            XlsxRow(1, height: 24, customHeight: true),
            XlsxRow(2, height: 15),
            XlsxRow(3),
          ],
          merges: ['A5:B5', 'C8:E8'],
        ),
      ]).sheet('S');
      expect(sheet.merges, ['A5:B5', 'C8:E8']);
      expect(sheet.columns[0].min, 1);
      expect(sheet.columns[0].max, 1);
      expect(sheet.columns[0].width, 28.33203125);
      expect(sheet.columns[0].style!.fontSize, 18);
      expect(sheet.columns[1].min, 2);
      expect(sheet.columns[1].max, 4);
      expect(sheet.columns[1].width, 21.88671875);
      expect(sheet.columns[1].style, isNull);
      expect(sheet.rows[1]!.height, 24);
      expect(sheet.rows[1]!.customHeight, isTrue);
      expect(sheet.rows[2]!.height, 15);
      expect(sheet.rows[2]!.customHeight, isFalse);
      expect(sheet.rows[3]!.height, isNull);
    });

    test('rows past the last Excel row, or out of order, are refused', () {
      expect(
        () => XlsxWorkbook([
          XlsxSheet('S', rows: const [XlsxRow(1048577)]),
        ]).toBytes(),
        throwsArgumentError,
      );
      expect(
        () => XlsxWorkbook([
          XlsxSheet('S', rows: const [XlsxRow(1048576)]),
        ]).toBytes(),
        returnsNormally,
      );
      expect(
        () => XlsxWorkbook([
          XlsxSheet('S', rows: const [XlsxRow(3), XlsxRow(2)]),
        ]).toBytes(),
        throwsArgumentError,
      );
    });

    test('non-finite numbers are refused', () {
      expect(
        () => XlsxWorkbook([
          XlsxSheet(
            'S',
            rows: [
              XlsxRow(1, cells: [XlsxCell.number(double.nan)]),
            ],
          ),
        ]).toBytes(),
        throwsArgumentError,
      );
    });
  });

  group('styles', () {
    test('fonts, format, alignment and borders come back as written', () {
      const base = CellStyle(fontSize: 18);
      final styles = [
        base,
        base.copyWith(bold: true),
        base.copyWith(italic: true),
        const CellStyle(fontName: 'Times New Roman', fontSize: 16, bold: true),
        base.copyWith(numberFormat: NumberFormat.thousands),
        base.copyWith(horizontal: HAlign.center, vertical: VAlign.center),
        base.copyWith(wrap: true),
        base.copyWith(borderTop: true, borderLeft: true),
        base.withAllBorders,
      ];
      final sheet = roundTrip([
        XlsxSheet(
          'S',
          rows: [
            XlsxRow(
              1,
              cells: [for (final s in styles) XlsxCell.empty(style: s)],
            ),
          ],
        ),
      ]).sheet('S');
      ReadStyle at(int i) => sheet.cell('${'ABCDEFGHI'[i]}1')!.style;

      expect(at(0).fontName, 'Calibri');
      expect(at(0).fontSize, 18);
      expect(at(0).bold, isFalse);
      expect(at(0).borders, isEmpty);
      expect(at(1).bold, isTrue);
      expect(at(2).italic, isTrue);
      expect(at(3).fontName, 'Times New Roman');
      expect(at(3).fontSize, 16);
      expect(at(3).bold, isTrue);
      expect(at(4).thousands, isTrue);
      expect(at(0).thousands, isFalse);
      expect(at(5).horizontal, 'center');
      expect(at(5).vertical, 'center');
      expect(at(6).wrap, isTrue);
      expect(at(7).borders, {'left': 'thin', 'top': 'thin'});
      expect(at(8).borders, {
        'left': 'thin',
        'right': 'thin',
        'top': 'thin',
        'bottom': 'thin',
      });
    });

    test('identical styles share one entry', () {
      const s = CellStyle(fontSize: 18, bold: true);
      final wb = roundTrip([
        XlsxSheet(
          'S',
          rows: [
            XlsxRow(
              1,
              cells: [
                const XlsxCell.text('a', style: s),
                const XlsxCell.text(
                  'b',
                  style: CellStyle(fontSize: 18, bold: true),
                ),
                const XlsxCell.number(1, style: s),
                const XlsxCell.text('c'),
              ],
            ),
          ],
        ),
      ]);
      final sheet = wb.sheet('S');
      expect(sheet.cell('A1')!.style.xfIndex, sheet.cell('B1')!.style.xfIndex);
      expect(sheet.cell('A1')!.style.xfIndex, sheet.cell('C1')!.style.xfIndex);
      // default + the one shared style.
      expect(wb.xfCount, 2);
      // Shared strings are shared too.
      expect(wb.sharedStringCount, 3);
    });
  });

  group('text safety', () {
    for (final t in [
      '=1+1',
      '+84',
      '-5',
      '@SUM(A1)',
      '=HYPERLINK("http://x")',
    ]) {
      test('"$t" stays a string cell with no formula and no apostrophe', () {
        final c = onlyCell(XlsxCell.text(t));
        expect(c.type, 'text');
        expect(c.text, t);
        expect(c.formula, isNull);
      });
    }

    test('no <f> element anywhere for text cells', () {
      final bytes = XlsxWorkbook([
        XlsxSheet(
          'S',
          rows: const [
            XlsxRow(1, cells: [XlsxCell.text('=1+1'), XlsxCell.text('@x')]),
          ],
        ),
      ]).toBytes();
      final wb = ReadWorkbook.read(bytes);
      expect(
        wb.sheet('S').cells.values.where((c) => c.type == 'formula'),
        isEmpty,
      );
    });

    test('<, & and quotes come back unchanged', () {
      const t = 'a < b & c > d "q" \'s\' &amp; <b>x</b>';
      expect(onlyCell(const XlsxCell.text(t)).text, t);
    });

    test('NUL, other control characters and lone surrogates are removed', () {
      final bad =
          'a\u0000b\u0001c\u000bd${String.fromCharCode(0xD800)}e'
          '${String.fromCharCode(0xDC00)}f￾g';
      expect(onlyCell(XlsxCell.text(bad)).text, 'abcdefg');
    });

    test('a valid surrogate pair (emoji) and tab survive', () {
      expect(onlyCell(const XlsxCell.text('x😀\ty')).text, 'x😀\ty');
    });

    test('Vietnamese text round-trips, precomposed and decomposed', () {
      const names = [
        'Xôi ruốc',
        'Thêm chả',
        'Trứng ngải cứu',
        'Xôi ruô̂́c', // decomposed
        'Trấng', // decomposed
      ];
      final wb = roundTrip([
        XlsxSheet(
          'S',
          rows: [
            XlsxRow(1, cells: [for (final n in names) XlsxCell.text(n)]),
          ],
        ),
      ]);
      for (final (i, n) in names.indexed) {
        expect(wb.sheet('S').cell('${'ABCDE'[i]}1')!.text, n);
      }
      expect(names[0] == names[3], isFalse);
    });

    test('newlines become a space unless the style wraps', () {
      final plain = onlyCell(const XlsxCell.text('a\nb\r\nc'));
      expect(plain.text, 'a b c');
      final wrapped = onlyCell(
        const XlsxCell.text('a\nb\r\nc', style: CellStyle(wrap: true)),
      );
      expect(wrapped.text, 'a\nb\nc');
    });

    test('leading and trailing spaces are kept', () {
      expect(onlyCell(const XlsxCell.text('  x  ')).text, '  x  ');
    });

    test('a sheet name with an XML character is escaped', () {
      final wb = roundTrip([XlsxSheet('a&b<c>')]);
      expect(wb.sheetNames, ['a&b<c>']);
    });
  });

  group('validation', () {
    ArgumentError? build(List<XlsxSheet> sheets) {
      try {
        XlsxWorkbook(sheets).toBytes();
      } on ArgumentError catch (e) {
        return e;
      }
      return null;
    }

    test('bad sheet names throw', () {
      expect(build([XlsxSheet('')]), isNotNull);
      expect(build([XlsxSheet('a' * 32)]), isNotNull);
      expect(build([XlsxSheet('a' * 31)]), isNull);
      expect(build([XlsxSheet('a/b')]), isNotNull);
      for (final ch in [':', r'\', '?', '*', '[', ']']) {
        expect(build([XlsxSheet('a${ch}b')]), isNotNull, reason: ch);
      }
      expect(build([XlsxSheet('x'), XlsxSheet('x')]), isNotNull);
      expect(build([XlsxSheet('x'), XlsxSheet('X')]), isNotNull);
      expect(build([XlsxSheet('gộp'), XlsxSheet('tách')]), isNull);
      expect(build([]), isNotNull);
    });

    test('overlapping or bad merges throw', () {
      expect(
        build([
          XlsxSheet('S', merges: ['A1:B2', 'B2:C3']),
        ]),
        isNotNull,
      );
      expect(
        build([
          XlsxSheet('S', merges: ['A1:C3', 'B2:B2']),
        ]),
        isNotNull,
      );
      expect(
        build([
          XlsxSheet('S', merges: ['A1:A1']),
        ]),
        isNotNull,
      );
      expect(
        build([
          XlsxSheet('S', merges: ['B2:A1']),
        ]),
        isNotNull,
      );
      expect(
        build([
          XlsxSheet('S', merges: ['nonsense']),
        ]),
        isNotNull,
      );
      expect(
        build([
          XlsxSheet('S', merges: ['A1:B1', 'A2:B2']),
        ]),
        isNull,
      );
    });

    test('overlapping columns throw', () {
      expect(
        build([
          XlsxSheet(
            'S',
            columns: const [XlsxColumn(1, 3, 10), XlsxColumn(3, 4, 10)],
          ),
        ]),
        isNotNull,
      );
    });
  });

  test('the same input twice gives identical bytes', () {
    List<int> make() => XlsxWorkbook([
      XlsxSheet(
        'S',
        columns: const [XlsxColumn(1, 2, 20)],
        rows: const [
          XlsxRow(1, cells: [XlsxCell.text('Xôi'), XlsxCell.number(1)]),
        ],
        merges: const ['A3:B3'],
      ),
    ]).toBytes();
    expect(make(), make());
  });
}
