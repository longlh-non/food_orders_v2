import 'dart:convert';

import 'package:food_orders_backend/orders_export.dart';
import 'package:test/test.dart';

Map<String, dynamic> order(
  String id,
  String placedAt, {
  String status = 'finished',
  String customer = 'Bao',
  List<Map<String, dynamic>>? items,
}) => {
  'id': id,
  'customerName': customer,
  'status': status,
  'placedAt': placedAt,
  'items':
      items ??
      [
        {'name': 'Xôi thịt', 'quantity': 1, 'price': 25000},
      ],
};

/// A small CSV reader for the round-trip test: `;`-separated, CRLF lines,
/// quoted cells with doubled quotes. Skips the BOM and the `sep=` line.
List<List<String>> readCsv(List<int> bytes) {
  var text = utf8.decode(bytes);
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ';') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      i++;
    } else {
      cell.write(c);
    }
  }
  // The `sep=;` line splits into ['sep=', '']; drop it by its first cell.
  return rows.where((r) => !r.first.startsWith('sep=')).toList();
}

void main() {
  group('isValidMonth', () {
    test('accepts 2026-11', () => expect(isValidMonth('2026-11'), isTrue));
    for (final bad in [
      '2026-13',
      '2026-00',
      '2026-1',
      '202611',
      '2026-11-01',
      '',
      '2026-11 ',
      '2026-11%',
    ]) {
      test('rejects "$bad"', () => expect(isValidMonth(bad), isFalse));
    }
  });

  group('ordersInMonth', () {
    test('keeps only that month, boundaries included correctly', () {
      final orders = [
        order('a', '2026-10-31T23:59:59.999'),
        order('b', '2026-11-01T00:00:00.000'),
        order('c', '2026-11-30T23:59:59.999'),
        order('d', '2026-12-01T00:00:00.000'),
      ];

      expect(ordersInMonth(orders, '2026-11').map((o) => o['id']), ['b', 'c']);
    });

    test('sorts oldest first and keeps input order on ties', () {
      final orders = [
        order('late', '2026-11-20T10:00:00.000'),
        order('tie1', '2026-11-05T08:00:00.000'),
        order('early', '2026-11-01T07:00:00.000'),
        order('tie2', '2026-11-05T08:00:00.000'),
      ];

      expect(ordersInMonth(orders, '2026-11').map((o) => o['id']), [
        'early',
        'tie1',
        'tie2',
        'late',
      ]);
    });

    test('returns an empty list when nothing matches', () {
      expect(
        ordersInMonth([order('a', '2026-10-01T00:00:00.000')], '2026-11'),
        isEmpty,
      );
    });
  });

  group('exportRows', () {
    test(
      'a line with toppings: unit = base + toppings, total = unit x qty',
      () {
        final rows = exportRows([
          order(
            '1794',
            '2026-11-12T12:34:56.000',
            items: [
              {
                'id': 'xoi-thit',
                'name': 'Xôi thịt',
                'quantity': 2,
                'price': 25000,
                'toppings': [
                  {'id': 'trung', 'name': 'Thêm trứng', 'price': 5000},
                  {'id': 'cha', 'name': 'Thêm chả', 'price': 10000},
                ],
              },
            ],
          ),
        ]);

        expect(rows, [
          [
            '2026-11-12',
            '12:34',
            '1794',
            'Bao',
            'Xôi thịt',
            2,
            40000,
            'Thêm trứng; Thêm chả',
            80000,
            'finished',
          ],
        ]);
      },
    );

    test('a finished order writes the raw status `finished`', () {
      final row = exportRows([
        order('1', '2026-11-01T08:00:00.000', status: 'finished'),
      ]).single;

      expect(row.last, 'finished');
    });

    test('an old line without id or toppings works', () {
      final row = exportRows([order('1', '2026-11-01T08:00:00.000')]).single;

      expect(row[6], 25000);
      expect(row[7], '');
      expect(row[8], 25000);
    });

    test('a two-line order gives two rows, order details repeated', () {
      final rows = exportRows([
        order(
          '7',
          '2026-11-02T09:00:00.000',
          items: [
            {'name': 'Xôi chả', 'quantity': 1, 'price': 25000},
            {'name': 'Trà đá', 'quantity': 3, 'price': 4000},
          ],
        ),
      ]);

      expect(rows, hasLength(2));
      expect(rows.map((r) => r[2]), ['7', '7']);
      expect(rows[1][8], 12000);
    });

    test('the same topping twice is counted twice', () {
      final row = exportRows([
        order(
          '1',
          '2026-11-01T08:00:00.000',
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
      ]).single;

      expect(row[6], 45000);
      expect(row[7], 'Thêm chả; Thêm chả');
    });

    test('the time is empty when placedAt has no time part', () {
      expect(exportRows([order('1', '2026-11-01')]).single[1], '');
    });
  });

  group('neutralise', () {
    for (final risky in [
      '=1+1',
      '+84',
      '-5',
      '@SUM(A1)',
      '\tx',
      '\rx',
      '  =x',
    ]) {
      test('prefixes ${jsonEncode(risky)}', () {
        expect(neutralise(risky), "'$risky");
      });
    }
    for (final safe in ['Nguyễn Văn A', 'Bánh mì', 'a=b', '']) {
      test('leaves ${jsonEncode(safe)} alone', () {
        expect(neutralise(safe), safe);
      });
    }

    test('applies to customer, item and topping text, never to numbers', () {
      final row = exportRows([
        order(
          '=id',
          '2026-11-01T08:00:00.000',
          customer: '=HYPERLINK("http://x")',
          items: [
            {
              'name': '+Xôi',
              'quantity': 1,
              'price': 25000,
              'toppings': [
                {'name': '@chả', 'price': 10000},
              ],
            },
          ],
        ),
      ]).single;

      expect(row[2], "'=id");
      expect(row[3], "'=HYPERLINK(\"http://x\")");
      expect(row[4], "'+Xôi");
      expect(row[7], "'@chả");
      expect(row[5], 1);
      expect(row[6], 35000);
    });
  });

  group('csvBytes', () {
    List<List<Object>> sample() => exportRows([
      order(
        '1',
        '2026-11-01T08:00:00.000',
        customer: 'Bảo; "Bờm"\nnhà 5',
        items: [
          {
            'name': 'Xôi ruốc',
            'quantity': 1,
            'price': 25000,
            'toppings': [
              {'name': 'Thêm chả', 'price': 10000},
            ],
          },
          {'name': 'Trứng ngải cứu', 'quantity': 2, 'price': 10000.0},
        ],
      ),
    ]);

    test('starts with the UTF-8 byte order mark', () {
      expect(csvBytes(sample()).take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('writes the sep= line only when asked', () {
      final withSep = utf8.decode(csvBytes(sample()).skip(3).toList());
      final without = utf8.decode(
        csvBytes(sample(), sepLine: false).skip(3).toList(),
      );

      expect(withSep, startsWith('sep=;\r\nNgày;Giờ;'));
      expect(without, startsWith('Ngày;Giờ;'));
    });

    test('uses CRLF line endings', () {
      final text = utf8.decode(csvBytes(sample()).skip(3).toList());

      expect(text.split('\r\n'), hasLength(5)); // sep, header, 2 rows, ''
      expect(text.replaceAll('\r\n', ''), isNot(contains('\r')));
    });

    test('quotes and doubles quotes where needed; numbers stay bare', () {
      final text = utf8.decode(csvBytes(sample()).skip(3).toList());

      expect(text, contains('"Bảo; ""Bờm""\nnhà 5"'));
      expect(text, contains(';35000;'));
      expect(text, contains(';20000;'), reason: '10000.0 x 2 written as 20000');
      expect(text, isNot(contains('.0;')));
      expect(text, isNot(contains('VNĐ')));
    });

    test('round trip keeps Vietnamese text exactly', () {
      final rows = readCsv(csvBytes(sample()));

      expect(rows.first, exportHeader);
      expect(rows[1][3], 'Bảo; "Bờm"\nnhà 5');
      expect(rows[1][4], 'Xôi ruốc');
      expect(rows[1][7], 'Thêm chả');
      expect(rows[2][4], 'Trứng ngải cứu');
      // Precomposed and combining forms are passed through untouched.
      const combining = 'Xôi';
      final custom = readCsv(
        csvBytes([
          ['2026-11-01', '', '1', combining, 'x', 1, 1, '', 1, 'pending'],
        ]),
      );
      expect(custom[1][3], combining);
    });

    test('an empty month gives BOM, sep line and header only', () {
      final bytes = csvBytes(exportRows([]));
      final text = utf8.decode(bytes.skip(3).toList());

      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(text, 'sep=;\r\n${exportHeader.join(';')}\r\n');
    });
  });

  group('more csv cases', () {
    test('a comma delimiter works and quotes cells containing commas', () {
      final rows = exportRows([
        order('1', '2026-11-01T08:00:00.000', customer: 'Bao, Bờm'),
      ]);
      final text = utf8.decode(csvBytes(rows, delimiter: ',').skip(3).toList());

      expect(text, startsWith('sep=,\r\nNgày,Giờ,'));
      expect(text, contains(',"Bao, Bờm",'));
    });

    test('non-whole and negative numbers are written as they are', () {
      final text = utf8.decode(
        csvBytes([
          ['2026-11-01', '', '1', 'x', 'y', 1, 9.5, '', -8000, 'pending'],
        ]).skip(3).toList(),
      );

      expect(text, contains(';9.5;'));
      expect(text, contains(';-8000;'));
    });

    test('the status cell is neutralised too', () {
      final row = exportRows([
        order('1', '2026-11-01T08:00:00.000', status: '=evil'),
      ]).single;

      expect(row[9], "'=evil");
    });

    test('a short placedAt goes in the date cell as it is, neutralised', () {
      final row = exportRows([order('1', '=1+1')]).single;

      expect(row[0], "'=1+1");
      expect(row[1], '');
    });
  });

  group('summarise', () {
    test('totals per status; cancelled left out of the grand total', () {
      final s = summarise([
        order('1', '2026-11-01T08:00:00.000'), // finished 25000
        order(
          '2',
          '2026-11-02T08:00:00.000',
          status: 'cancelled',
          items: [
            {'name': 'Mì tôm bò', 'quantity': 1, 'price': 30000},
          ],
        ),
        order(
          '3',
          '2026-11-03T08:00:00.000',
          status: 'pending',
          items: [
            {'name': 'Trà đá', 'quantity': 2, 'price': 4000},
            {'name': 'Lavie', 'quantity': 1, 'price': 6000},
          ],
        ),
      ]);

      expect(s.orders, 3);
      expect(s.lines, 4);
      expect(s.totalsByStatus, {
        'finished': 25000,
        'cancelled': 30000,
        'pending': 14000,
      });
      expect(s.grandTotal, 39000);
      expect(s.nonWholeLines, 0);
    });

    test('counts lines with a non-whole price (old USD test data)', () {
      final s = summarise([
        order(
          'old',
          '2026-11-01T08:00:00.000',
          items: [
            {'name': 'Classic Burger', 'quantity': 1, 'price': 9.5},
            {'name': 'Xôi thịt', 'quantity': 1, 'price': 25000},
          ],
        ),
      ]);

      expect(s.nonWholeLines, 1);
    });
  });
}
