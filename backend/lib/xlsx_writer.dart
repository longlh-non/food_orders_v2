// Only the in-memory part of `archive`. Never import `archive_io.dart` here:
// it pulls in `posix` (FFI to the system libc), which this code doesn't need.
import 'package:archive/archive.dart';

import 'dart:convert';

/// A small `.xlsx` writer. Pure: no files, no database. It builds the whole
/// workbook in memory and returns the bytes of the zip.
///
/// It only knows what the two report layouts need: text, number and formula
/// cells, a few cell styles, column widths, row heights and merged ranges.

/// Excel's limits.
const int _maxRow = 1048576;
const int _maxCol = 16384;
const int _maxCellChars = 32767;

/// How a cell's number is shown.
enum NumberFormat {
  /// Excel's "General".
  general,

  /// Excel's built-in format 3, `#,##0`.
  thousands,
}

enum HAlign { general, center }

enum VAlign { bottom, center }

/// The look of a cell. Immutable; equal styles share one entry in the file.
class CellStyle {
  const CellStyle({
    this.fontName = 'Calibri',
    this.fontSize = 11,
    this.bold = false,
    this.italic = false,
    this.numberFormat = NumberFormat.general,
    this.horizontal = HAlign.general,
    this.vertical = VAlign.bottom,
    this.wrap = false,
    this.borderTop = false,
    this.borderRight = false,
    this.borderBottom = false,
    this.borderLeft = false,
  });

  final String fontName;
  final double fontSize;
  final bool bold;
  final bool italic;
  final NumberFormat numberFormat;
  final HAlign horizontal;
  final VAlign vertical;
  final bool wrap;

  /// Each edge is either none (false) or thin (true).
  final bool borderTop;
  final bool borderRight;
  final bool borderBottom;
  final bool borderLeft;

  CellStyle copyWith({
    String? fontName,
    double? fontSize,
    bool? bold,
    bool? italic,
    NumberFormat? numberFormat,
    HAlign? horizontal,
    VAlign? vertical,
    bool? wrap,
    bool? borderTop,
    bool? borderRight,
    bool? borderBottom,
    bool? borderLeft,
  }) => CellStyle(
    fontName: fontName ?? this.fontName,
    fontSize: fontSize ?? this.fontSize,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    numberFormat: numberFormat ?? this.numberFormat,
    horizontal: horizontal ?? this.horizontal,
    vertical: vertical ?? this.vertical,
    wrap: wrap ?? this.wrap,
    borderTop: borderTop ?? this.borderTop,
    borderRight: borderRight ?? this.borderRight,
    borderBottom: borderBottom ?? this.borderBottom,
    borderLeft: borderLeft ?? this.borderLeft,
  );

  /// Thin border on all four edges.
  CellStyle get withAllBorders => copyWith(
    borderTop: true,
    borderRight: true,
    borderBottom: true,
    borderLeft: true,
  );

  @override
  bool operator ==(Object other) =>
      other is CellStyle &&
      other.fontName == fontName &&
      other.fontSize == fontSize &&
      other.bold == bold &&
      other.italic == italic &&
      other.numberFormat == numberFormat &&
      other.horizontal == horizontal &&
      other.vertical == vertical &&
      other.wrap == wrap &&
      other.borderTop == borderTop &&
      other.borderRight == borderRight &&
      other.borderBottom == borderBottom &&
      other.borderLeft == borderLeft;

  @override
  int get hashCode => Object.hash(
    fontName,
    fontSize,
    bold,
    italic,
    numberFormat,
    horizontal,
    vertical,
    wrap,
    borderTop,
    borderRight,
    borderBottom,
    borderLeft,
  );
}

/// One cell. Text is always written as a string cell, never as a formula,
/// whatever it starts with.
class XlsxCell {
  /// Text, kept as text even if it starts with `=`, `+`, `-` or `@`.
  const XlsxCell.text(String this.text, {this.style = const CellStyle()})
    : number = null,
      formula = null;

  const XlsxCell.number(num this.number, {this.style = const CellStyle()})
    : text = null,
      formula = null;

  /// A formula (without the leading `=`) and its cached value, so a viewer
  /// that doesn't recalculate still shows the number.
  const XlsxCell.formula(
    String this.formula,
    num cached, {
    this.style = const CellStyle(),
  }) : number = cached,
       text = null;

  /// No content, only a style (for example a border).
  const XlsxCell.empty({this.style = const CellStyle()})
    : text = null,
      number = null,
      formula = null;

  final String? text;
  final num? number;
  final String? formula;
  final CellStyle style;
}

/// A row. [index] is 1-based. [cells] start at column A; `null` skips a
/// column. [height] is in points; [customHeight] marks it as set by hand.
class XlsxRow {
  const XlsxRow(
    this.index, {
    this.cells = const [],
    this.height,
    this.customHeight = false,
  });

  final int index;
  final List<XlsxCell?> cells;
  final double? height;
  final bool customHeight;
}

/// A column range, 1-based and inclusive, with a width and default style.
class XlsxColumn {
  const XlsxColumn(this.min, this.max, this.width, {this.style});

  final int min;
  final int max;
  final double width;
  final CellStyle? style;
}

class XlsxSheet {
  /// [rows] must be in ascending order of [XlsxRow.index]. [merges] are
  /// ranges like `A5:B5`.
  XlsxSheet(
    this.name, {
    this.columns = const [],
    this.rows = const [],
    this.merges = const [],
  });

  final String name;
  final List<XlsxColumn> columns;
  final List<XlsxRow> rows;
  final List<String> merges;
}

class XlsxWorkbook {
  XlsxWorkbook(this.sheets);

  final List<XlsxSheet> sheets;

  /// The bytes of the `.xlsx` file. The same input gives the same bytes.
  List<int> toBytes() => _Builder(sheets).build();
}

// ---------------------------------------------------------------------------

/// `A`, `B`, ... `XFD` for a 1-based column.
String columnName(int column) {
  if (column < 1 || column > _maxCol) {
    throw ArgumentError.value(column, 'column', 'must be 1..$_maxCol');
  }
  var n = column;
  final out = <int>[];
  while (n > 0) {
    n--;
    out.add(65 + n % 26);
    n ~/= 26;
  }
  return String.fromCharCodes(out.reversed);
}

final _refPattern = RegExp(r'^([A-Z]{1,3})([1-9][0-9]{0,6})$');

(int col, int row) _parseRef(String ref) {
  final m = _refPattern.firstMatch(ref);
  if (m == null) throw ArgumentError.value(ref, 'reference');
  var col = 0;
  for (final c in m.group(1)!.codeUnits) {
    col = col * 26 + (c - 64);
  }
  final row = int.parse(m.group(2)!);
  if (col > _maxCol || row > _maxRow) {
    throw ArgumentError.value(ref, 'reference', 'outside the sheet');
  }
  return (col, row);
}

const _badSheetChars = ':\\/?*[]';

void _checkSheetName(String name, Set<String> seen) {
  if (name.isEmpty || name.length > 31) {
    throw ArgumentError.value(name, 'sheet name', 'must be 1-31 characters');
  }
  for (final unit in name.codeUnits) {
    if (_badSheetChars.contains(String.fromCharCode(unit)) || unit < 0x20) {
      throw ArgumentError.value(name, 'sheet name', 'has a forbidden char');
    }
  }
  if (name.startsWith("'") || name.endsWith("'")) {
    throw ArgumentError.value(name, 'sheet name', 'can\'t start or end in \'');
  }
  if (!seen.add(name.toLowerCase())) {
    throw ArgumentError.value(name, 'sheet name', 'is used twice');
  }
}

/// Removes what XML 1.0 can't hold: control characters except tab, newline
/// and carriage return, unpaired surrogates, U+FFFE and U+FFFF.
String _stripInvalid(String s) {
  final out = StringBuffer();
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final u = units[i];
    if (u >= 0xD800 && u <= 0xDBFF) {
      if (i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] <= 0xDFFF) {
        out.writeCharCode(u);
        out.writeCharCode(units[i + 1]);
        i++;
      }
    } else if (u >= 0xDC00 && u <= 0xDFFF) {
      // lone low surrogate: dropped
    } else if (u == 0x9 || u == 0xA || u == 0xD || (u >= 0x20 && u <= 0xFFFD)) {
      out.writeCharCode(u);
    }
  }
  return out.toString();
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String _cellText(String raw, {required bool wrap}) {
  var s = _stripInvalid(raw);
  s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (!wrap) s = s.replaceAll('\n', ' ');
  if (s.length > _maxCellChars) {
    s = s.substring(0, _maxCellChars);
    final last = s.codeUnitAt(s.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF) s = s.substring(0, s.length - 1);
  }
  return s;
}

String _num(num n) {
  if (!n.isFinite) throw ArgumentError.value(n, 'number', 'must be finite');
  if (n is double && n == n.truncateToDouble() && n.abs() < 1e15) {
    return n.truncate().toString();
  }
  return n.toString();
}

class _Builder {
  _Builder(this.sheets);

  final List<XlsxSheet> sheets;

  final _xfs = <CellStyle, int>{const CellStyle(): 0};
  final _fonts = <String, int>{};
  final _fontXml = <String>[];
  final _borders = <String, int>{};
  final _borderXml = <String>[];
  final _strings = <String, int>{};
  var _stringRefs = 0;

  int _styleId(CellStyle style) => _xfs.putIfAbsent(style, () => _xfs.length);

  int _fontId(CellStyle s) {
    final xml =
        '<font>${s.bold ? '<b/>' : ''}${s.italic ? '<i/>' : ''}'
        '<sz val="${_num(s.fontSize)}"/><name val="${_escape(_stripInvalid(s.fontName))}"/>'
        '<family val="2"/></font>';
    return _fonts.putIfAbsent(xml, () {
      _fontXml.add(xml);
      return _fontXml.length - 1;
    });
  }

  int _borderId(CellStyle s) {
    String edge(String tag, bool on) =>
        on ? '<$tag style="thin"><color auto="1"/></$tag>' : '<$tag/>';
    final xml =
        '<border>${edge('left', s.borderLeft)}${edge('right', s.borderRight)}'
        '${edge('top', s.borderTop)}${edge('bottom', s.borderBottom)}<diagonal/></border>';
    return _borders.putIfAbsent(xml, () {
      _borderXml.add(xml);
      return _borderXml.length - 1;
    });
  }

  int _stringId(String s) {
    _stringRefs++;
    return _strings.putIfAbsent(s, () => _strings.length);
  }

  List<int> build() {
    if (sheets.isEmpty) throw ArgumentError('a workbook needs a sheet');
    final seen = <String>{};
    for (final sheet in sheets) {
      _checkSheetName(sheet.name, seen);
    }
    // Font 0 and border 0 are the default style's.
    _fontId(const CellStyle());
    _borderId(const CellStyle());

    final sheetXml = [for (final sheet in sheets) _sheetXml(sheet)];

    final parts = <String, String>{
      '[Content_Types].xml': _contentTypes(),
      '_rels/.rels': _rootRels(),
      'xl/workbook.xml': _workbook(),
      'xl/_rels/workbook.xml.rels': _workbookRels(),
      'xl/styles.xml': _styles(),
      'xl/sharedStrings.xml': _sharedStrings(),
      for (final (i, xml) in sheetXml.indexed)
        'xl/worksheets/sheet${i + 1}.xml': xml,
    };

    // Fixed timestamps (also the creation time) keep the bytes identical.
    final fixed = DateTime(1980, 1, 1).millisecondsSinceEpoch ~/ 1000;
    final archive = Archive();
    for (final e in parts.entries) {
      final file = ArchiveFile.bytes(e.key, utf8.encode(e.value));
      file.lastModTime = fixed;
      file.creationTime = fixed;
      archive.add(file);
    }
    return ZipEncoder().encodeBytes(archive, modified: DateTime(1980, 1, 1));
  }

  static const _xmlHead =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
  static const _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
  static const _rns =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  String _contentTypes() {
    final b = StringBuffer(_xmlHead)
      ..write(
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
      );
    for (var i = 1; i <= sheets.length; i++) {
      b.write(
        '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }
    b.write(
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
      '</Types>',
    );
    return b.toString();
  }

  String _rootRels() =>
      '$_xmlHead<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="$_rns/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  String _workbook() {
    final b = StringBuffer(_xmlHead)
      ..write('<workbook xmlns="$_ns" xmlns:r="$_rns"><sheets>');
    for (final (i, s) in sheets.indexed) {
      b.write(
        '<sheet name="${_escape(s.name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>',
      );
    }
    b.write('</sheets><calcPr fullCalcOnLoad="1"/></workbook>');
    return b.toString();
  }

  String _workbookRels() {
    final b = StringBuffer(_xmlHead)
      ..write(
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
      );
    for (var i = 1; i <= sheets.length; i++) {
      b.write(
        '<Relationship Id="rId$i" Type="$_rns/worksheet" Target="worksheets/sheet$i.xml"/>',
      );
    }
    final n = sheets.length;
    b.write(
      '<Relationship Id="rId${n + 1}" Type="$_rns/styles" Target="styles.xml"/>'
      '<Relationship Id="rId${n + 2}" Type="$_rns/sharedStrings" Target="sharedStrings.xml"/>'
      '</Relationships>',
    );
    return b.toString();
  }

  String _styles() {
    final xfs = StringBuffer();
    for (final style in _xfs.keys) {
      final align =
          style.horizontal != HAlign.general ||
              style.vertical != VAlign.bottom ||
              style.wrap
          ? '<alignment${style.horizontal == HAlign.center ? ' horizontal="center"' : ''}'
                '${style.vertical == VAlign.center ? ' vertical="center"' : ''}'
                '${style.wrap ? ' wrapText="1"' : ''}/>'
          : '';
      final numFmt = style.numberFormat == NumberFormat.thousands ? 3 : 0;
      final attrs =
          'numFmtId="$numFmt" fontId="${_fontId(style)}" fillId="0" borderId="${_borderId(style)}" xfId="0"'
          '${numFmt != 0 ? ' applyNumberFormat="1"' : ''} applyFont="1" applyBorder="1"'
          '${align.isNotEmpty ? ' applyAlignment="1"' : ''}';
      xfs.write(align.isEmpty ? '<xf $attrs/>' : '<xf $attrs>$align</xf>');
    }
    return '$_xmlHead<styleSheet xmlns="$_ns">'
        '<fonts count="${_fontXml.length}">${_fontXml.join()}</fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="${_borderXml.length}">${_borderXml.join()}</borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="${_xfs.length}">$xfs</cellXfs>'
        '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
        '</styleSheet>';
  }

  String _sharedStrings() {
    final b = StringBuffer(_xmlHead)
      ..write(
        '<sst xmlns="$_ns" count="$_stringRefs" uniqueCount="${_strings.length}">',
      );
    for (final s in _strings.keys) {
      b.write('<si><t xml:space="preserve">${_escape(s)}</t></si>');
    }
    b.write('</sst>');
    return b.toString();
  }

  String _sheetXml(XlsxSheet sheet) {
    final b = StringBuffer(_xmlHead)
      ..write('<worksheet xmlns="$_ns" xmlns:r="$_rns">')
      ..write('<sheetFormatPr defaultRowHeight="15"/>');

    // Columns: ascending and not overlapping.
    var lastMax = 0;
    for (final c in sheet.columns) {
      if (c.min < 1 ||
          c.max < c.min ||
          c.max > _maxCol ||
          c.min <= lastMax ||
          !c.width.isFinite ||
          c.width < 0 ||
          c.width > 255) {
        throw ArgumentError(
          'bad or overlapping column range ${c.min}-${c.max}',
        );
      }
      lastMax = c.max;
    }
    if (sheet.columns.isNotEmpty) {
      b.write('<cols>');
      for (final c in sheet.columns) {
        final s = c.style == null ? '' : ' style="${_styleId(c.style!)}"';
        b.write(
          '<col min="${c.min}" max="${c.max}" width="${_num(c.width)}"$s customWidth="1"/>',
        );
      }
      b.write('</cols>');
    }

    b.write('<sheetData>');
    var lastRow = 0;
    for (final row in sheet.rows) {
      if (row.index < 1 || row.index > _maxRow) {
        throw ArgumentError.value(row.index, 'row', 'must be 1..$_maxRow');
      }
      if (row.index <= lastRow) {
        throw ArgumentError.value(row.index, 'row', 'rows must ascend');
      }
      lastRow = row.index;
      if (row.cells.length > _maxCol) {
        throw ArgumentError('row ${row.index} has too many cells');
      }
      final h = row.height;
      if (h != null && (!h.isFinite || h < 0 || h > 409.5)) {
        throw ArgumentError.value(h, 'height', 'must be 0..409.5');
      }
      b.write('<row r="${row.index}"');
      if (h != null) {
        b.write(
          ' ht="${_num(h)}"${row.customHeight ? ' customHeight="1"' : ''}',
        );
      }
      b.write('>');
      for (final (i, cell) in row.cells.indexed) {
        if (cell != null) {
          b.write(_cellXml('${columnName(i + 1)}${row.index}', cell));
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData>');

    if (sheet.merges.isNotEmpty) {
      final taken = <(int, int, int, int)>[];
      b.write('<mergeCells count="${sheet.merges.length}">');
      for (final m in sheet.merges) {
        final parts = m.split(':');
        if (parts.length != 2) throw ArgumentError.value(m, 'merge');
        final (c1, r1) = _parseRef(parts[0]);
        final (c2, r2) = _parseRef(parts[1]);
        if (c2 < c1 || r2 < r1 || (c1 == c2 && r1 == r2)) {
          throw ArgumentError.value(m, 'merge', 'not a range');
        }
        for (final (a, b2, c, d) in taken) {
          if (c1 <= c && c2 >= a && r1 <= d && r2 >= b2) {
            throw ArgumentError.value(m, 'merge', 'overlaps another merge');
          }
        }
        taken.add((c1, r1, c2, r2));
        b.write('<mergeCell ref="${_escape(m)}"/>');
      }
      b.write('</mergeCells>');
    }
    b.write('</worksheet>');
    return b.toString();
  }

  String _cellXml(String ref, XlsxCell cell) {
    final s = _styleId(cell.style);
    final style = s == 0 ? '' : ' s="$s"';
    final text = cell.text;
    if (text != null) {
      final id = _stringId(_cellText(text, wrap: cell.style.wrap));
      return '<c r="$ref"$style t="s"><v>$id</v></c>';
    }
    final formula = cell.formula;
    if (formula != null) {
      var f = _stripInvalid(formula).replaceAll(RegExp(r'[\r\n]'), ' ');
      if (f.startsWith('=')) f = f.substring(1);
      return '<c r="$ref"$style><f>${_escape(f)}</f><v>${_num(cell.number!)}</v></c>';
    }
    if (cell.number != null) {
      return '<c r="$ref"$style><v>${_num(cell.number!)}</v></c>';
    }
    return '<c r="$ref"$style/>';
  }
}
