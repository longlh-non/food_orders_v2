// Only the in-memory part of `archive`; `archive_io.dart` would pull in
// `posix` (FFI to libc).
import 'package:archive/archive.dart';

import 'dart:convert';

import 'package:xml/xml.dart';

/// Test helper: reads the bytes of an `.xlsx` back into plain Dart values, so
/// layout tests can assert on what a spreadsheet program would see.

class ReadStyle {
  ReadStyle({
    required this.xfIndex,
    required this.fontName,
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.numFmtId,
    required this.horizontal,
    required this.vertical,
    required this.wrap,
    required this.borders,
  });

  final int xfIndex;
  final String fontName;
  final double fontSize;
  final bool bold;
  final bool italic;
  final int numFmtId;
  final String? horizontal;
  final String? vertical;
  final bool wrap;

  /// The edges that have a border, with their style: `{left: thin}`.
  final Map<String, String> borders;

  bool get thousands => numFmtId == 3;

  @override
  String toString() =>
      'ReadStyle(xf $xfIndex, $fontName $fontSize, bold $bold, italic $italic,'
      ' fmt $numFmtId, h $horizontal, v $vertical, wrap $wrap, $borders)';
}

class ReadCell {
  ReadCell({
    required this.ref,
    required this.type,
    required this.style,
    this.text,
    this.number,
    this.formula,
  });

  final String ref;

  /// `text`, `number`, `formula` or `empty`.
  final String type;
  final ReadStyle style;
  final String? text;

  /// The number, or a formula's cached value.
  final num? number;
  final String? formula;

  /// The text, or the number, or null: whichever the cell shows.
  Object? get value => text ?? number;
}

class ReadColumn {
  ReadColumn(this.min, this.max, this.width, this.style);

  final int min;
  final int max;
  final double width;
  final ReadStyle? style;
}

class ReadRow {
  ReadRow(this.height, this.customHeight);

  final double? height;
  final bool customHeight;
}

class ReadSheet {
  ReadSheet(this.name, this.cells, this.merges, this.columns, this.rows);

  final String name;
  final Map<String, ReadCell> cells;
  final List<String> merges;
  final List<ReadColumn> columns;
  final Map<int, ReadRow> rows;

  ReadCell? cell(String ref) => cells[ref];
}

class ReadWorkbook {
  ReadWorkbook._(
    this.partNames,
    this.sheets,
    this.contentTypeOverrides,
    this.relationshipTargets,
    this.fullCalcOnLoad,
    this.xfCount,
    this.sharedStringCount,
  );

  /// Zip entry names, in file order.
  final List<String> partNames;
  final List<ReadSheet> sheets;
  final List<String> contentTypeOverrides;

  /// Every relationship target, as a part name inside the zip.
  final List<String> relationshipTargets;
  final bool fullCalcOnLoad;

  /// Number of entries in `cellXfs` (identical styles share one).
  final int xfCount;
  final int sharedStringCount;

  List<String> get sheetNames => [for (final s in sheets) s.name];

  ReadSheet sheet(String name) => sheets.firstWhere((s) => s.name == name);

  /// Unzips and parses every part; throws if the zip or any XML part isn't
  /// well-formed.
  static ReadWorkbook read(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docs = <String, XmlDocument>{};
    final names = <String>[];
    for (final f in archive.files) {
      names.add(f.name);
      docs[f.name] = XmlDocument.parse(utf8.decode(f.content as List<int>));
    }
    XmlDocument doc(String name) =>
        docs[name] ?? (throw StateError('missing part $name'));

    final strings = [
      for (final si in doc('xl/sharedStrings.xml').findAllElements('si'))
        si.findAllElements('t').map((t) => t.innerText).join(),
    ];

    // Styles.
    final styles = doc('xl/styles.xml');
    final fonts = styles.findAllElements('font').toList();
    final borders = styles.findAllElements('border').toList();
    final xfs = styles
        .findElements('styleSheet')
        .first
        .findElements('cellXfs')
        .first
        .findElements('xf')
        .toList();
    final readStyles = <ReadStyle>[];
    for (final (i, xf) in xfs.indexed) {
      final font = fonts[int.parse(xf.getAttribute('fontId')!)];
      final border = borders[int.parse(xf.getAttribute('borderId')!)];
      final align = xf.findElements('alignment').firstOrNull;
      readStyles.add(
        ReadStyle(
          xfIndex: i,
          fontName: font.findElements('name').first.getAttribute('val')!,
          fontSize: double.parse(
            font.findElements('sz').first.getAttribute('val')!,
          ),
          bold: font.findElements('b').isNotEmpty,
          italic: font.findElements('i').isNotEmpty,
          numFmtId: int.parse(xf.getAttribute('numFmtId')!),
          horizontal: align?.getAttribute('horizontal'),
          vertical: align?.getAttribute('vertical'),
          wrap: align?.getAttribute('wrapText') == '1',
          borders: {
            for (final edge in ['left', 'right', 'top', 'bottom'])
              edge: ?border.findElements(edge).first.getAttribute('style'),
          },
        ),
      );
    }

    // Relationships.
    final targets = <String>[];
    for (final name in names.where((n) => n.endsWith('.rels'))) {
      final base = name == '_rels/.rels' ? '' : 'xl/';
      for (final r in doc(name).findAllElements('Relationship')) {
        targets.add('$base${r.getAttribute('Target')}');
      }
    }

    // Sheets, in workbook order.
    final wb = doc('xl/workbook.xml');
    final rels = {
      for (final r in doc(
        'xl/_rels/workbook.xml.rels',
      ).findAllElements('Relationship'))
        r.getAttribute('Id')!: r.getAttribute('Target')!,
    };
    final sheets = <ReadSheet>[];
    for (final s in wb.findAllElements('sheet')) {
      final target = rels[s.getAttribute('id', namespaceUri: '*')]!;
      sheets.add(
        _readSheet(
          s.getAttribute('name')!,
          doc('xl/$target'),
          strings,
          readStyles,
        ),
      );
    }

    return ReadWorkbook._(
      names,
      sheets,
      [
        for (final o in doc('[Content_Types].xml').findAllElements('Override'))
          o.getAttribute('PartName')!,
      ],
      targets,
      wb.findAllElements('calcPr').first.getAttribute('fullCalcOnLoad') == '1',
      xfs.length,
      strings.length,
    );
  }

  static ReadSheet _readSheet(
    String name,
    XmlDocument doc,
    List<String> strings,
    List<ReadStyle> styles,
  ) {
    final cells = <String, ReadCell>{};
    final rows = <int, ReadRow>{};
    for (final row in doc.findAllElements('row')) {
      final ht = row.getAttribute('ht');
      rows[int.parse(row.getAttribute('r')!)] = ReadRow(
        ht == null ? null : double.parse(ht),
        row.getAttribute('customHeight') == '1',
      );
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r')!;
        final style = styles[int.parse(c.getAttribute('s') ?? '0')];
        final f = c.findElements('f').firstOrNull;
        final v = c.findElements('v').firstOrNull?.innerText;
        if (c.getAttribute('t') == 's') {
          cells[ref] = ReadCell(
            ref: ref,
            type: 'text',
            style: style,
            text: strings[int.parse(v!)],
          );
        } else if (f != null) {
          cells[ref] = ReadCell(
            ref: ref,
            type: 'formula',
            style: style,
            formula: f.innerText,
            number: num.parse(v!),
          );
        } else if (v != null) {
          cells[ref] = ReadCell(
            ref: ref,
            type: 'number',
            style: style,
            number: num.parse(v),
          );
        } else {
          cells[ref] = ReadCell(ref: ref, type: 'empty', style: style);
        }
      }
    }
    return ReadSheet(
      name,
      cells,
      [
        for (final m in doc.findAllElements('mergeCell'))
          m.getAttribute('ref')!,
      ],
      [
        for (final c in doc.findAllElements('col'))
          ReadColumn(
            int.parse(c.getAttribute('min')!),
            int.parse(c.getAttribute('max')!),
            double.parse(c.getAttribute('width')!),
            c.getAttribute('style') == null
                ? null
                : styles[int.parse(c.getAttribute('style')!)],
          ),
      ],
      rows,
    );
  }
}
