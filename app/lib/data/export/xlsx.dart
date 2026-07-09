/// A tiny, pure-Dart writer for the Office Open XML (`.xlsx`) SpreadsheetML
/// format — just enough to emit the offline budget workbook.
///
/// We write the OOXML parts by hand rather than adding a spreadsheet package:
/// the format we need is a handful of small XML files zipped together (via
/// `package:archive`, already a dependency), and rolling our own keeps the
/// dependency surface flat *and*, crucially, lets us honour the money invariant.
/// Numbers are emitted as **pre-formatted decimal strings** derived straight
/// from integer cents (see [XlsxCell.number]); no value ever passes through a
/// `double`, so cents can neither be created nor destroyed by float rounding.
///
/// Pure Dart, zero Flutter imports: the model ([XlsxWorkbook]/[XlsxSheet]) and
/// the byte encoder ([encodeXlsx]) are exhaustively unit-testable.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One cell. A cell is either an inline string ([XlsxCell.text]) or a numeric
/// value carried as an already-formatted decimal literal ([XlsxCell.number]).
class XlsxCell {
  const XlsxCell._(this.value, {required this.isNumber, this.bold = false});

  /// A text cell. `null` or an empty string renders as a blank cell.
  const XlsxCell.text(String? value, {bool bold = false})
      : this._(value ?? '', isNumber: false, bold: bold);

  /// A numeric cell whose value is the decimal [literal] — e.g. the output of
  /// `Money.format()` (`"12.34"`, `"-0.05"`) or a plain integer string. The
  /// literal is written verbatim into the sheet's `<v>`; it must already be a
  /// valid number with no grouping or currency symbol. Kept as a string on
  /// purpose so money never touches a binary float.
  const XlsxCell.number(String literal, {bool bold = false})
      : this._(literal, isNumber: true, bold: bold);

  /// The empty cell.
  static const XlsxCell empty = XlsxCell.text('');

  final String value;
  final bool isNumber;
  final bool bold;

  bool get isBlank => !isNumber && value.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is XlsxCell &&
      other.value == value &&
      other.isNumber == isNumber &&
      other.bold == bold;

  @override
  int get hashCode => Object.hash(value, isNumber, bold);
}

/// One worksheet: a [name] (the tab label), a [header] row (rendered bold), and
/// the data [rows]. Rows may be ragged; short rows simply leave later columns
/// blank.
class XlsxSheet {
  const XlsxSheet({
    required this.name,
    required this.header,
    required this.rows,
  });

  final String name;
  final List<String> header;
  final List<List<XlsxCell>> rows;
}

/// A workbook: an ordered list of [sheets].
class XlsxWorkbook {
  const XlsxWorkbook(this.sheets);

  final List<XlsxSheet> sheets;

  /// Looks a sheet up by tab name, or null when absent.
  XlsxSheet? sheet(String name) {
    for (final s in sheets) {
      if (s.name == name) return s;
    }
    return null;
  }
}

/// Encodes [workbook] into the bytes of a valid `.xlsx` file (a zip of OOXML
/// parts). Deterministic: the same workbook always yields byte-identical output.
Uint8List encodeXlsx(XlsxWorkbook workbook) {
  final archive = Archive()
    ..addFile(_file('[Content_Types].xml', _contentTypes(workbook)))
    ..addFile(_file('_rels/.rels', _rootRels))
    ..addFile(_file('xl/workbook.xml', _workbookXml(workbook)))
    ..addFile(_file('xl/_rels/workbook.xml.rels', _workbookRels(workbook)))
    ..addFile(_file('xl/styles.xml', _stylesXml));
  for (var i = 0; i < workbook.sheets.length; i++) {
    archive.addFile(
      _file('xl/worksheets/sheet${i + 1}.xml', _sheetXml(workbook.sheets[i])),
    );
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}

ArchiveFile _file(String name, String xml) =>
    ArchiveFile.bytes(name, utf8.encode(xml));

const String _xmlDecl = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
const String _nsMain =
    'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const String _nsR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

const String _rootRels = '$_xmlDecl\n'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
    'Target="xl/workbook.xml"/>'
    '</Relationships>';

/// Two cell formats: plain (0) and bold (1). Bold is used for header rows.
const String _stylesXml = '$_xmlDecl\n'
    '<styleSheet xmlns="$_nsMain">'
    '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
    '<borders count="1"><border/></borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="2">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '</cellXfs>'
    '</styleSheet>';

String _contentTypes(XlsxWorkbook workbook) {
  final overrides = StringBuffer();
  for (var i = 0; i < workbook.sheets.length; i++) {
    overrides.write(
      '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    );
  }
  return '$_xmlDecl\n'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '$overrides'
      '</Types>';
}

String _workbookXml(XlsxWorkbook workbook) {
  final sheets = StringBuffer();
  for (var i = 0; i < workbook.sheets.length; i++) {
    sheets.write(
      '<sheet name="${_attr(workbook.sheets[i].name)}" '
      'sheetId="${i + 1}" r:id="rId${i + 1}"/>',
    );
  }
  return '$_xmlDecl\n'
      '<workbook xmlns="$_nsMain" xmlns:r="$_nsR">'
      '<sheets>$sheets</sheets>'
      '</workbook>';
}

String _workbookRels(XlsxWorkbook workbook) {
  final rels = StringBuffer();
  for (var i = 0; i < workbook.sheets.length; i++) {
    rels.write(
      '<Relationship Id="rId${i + 1}" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet${i + 1}.xml"/>',
    );
  }
  // Styles part gets the id after the last sheet.
  rels.write(
    '<Relationship Id="rId${workbook.sheets.length + 1}" '
    'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
    'Target="styles.xml"/>',
  );
  return '$_xmlDecl\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '$rels'
      '</Relationships>';
}

String _sheetXml(XlsxSheet sheet) {
  final data = StringBuffer();
  var rowNum = 1;
  final headerCells = [
    for (final label in sheet.header) XlsxCell.text(label, bold: true),
  ];
  data.write(_rowXml(rowNum++, headerCells));
  for (final row in sheet.rows) {
    data.write(_rowXml(rowNum++, row));
  }
  return '$_xmlDecl\n'
      '<worksheet xmlns="$_nsMain"><sheetData>$data</sheetData></worksheet>';
}

String _rowXml(int rowNum, List<XlsxCell> cells) {
  final buffer = StringBuffer('<row r="$rowNum">');
  for (var col = 0; col < cells.length; col++) {
    final cell = cells[col];
    if (cell.isBlank && !cell.bold) continue;
    final ref = '${_columnName(col)}$rowNum';
    final style = cell.bold ? ' s="1"' : '';
    if (cell.isNumber) {
      buffer.write('<c r="$ref"$style><v>${_text(cell.value)}</v></c>');
    } else if (cell.value.isEmpty) {
      buffer.write('<c r="$ref"$style/>');
    } else {
      buffer.write(
        '<c r="$ref"$style t="inlineStr">'
        '<is><t xml:space="preserve">${_text(cell.value)}</t></is></c>',
      );
    }
  }
  buffer.write('</row>');
  return buffer.toString();
}

/// The spreadsheet column name for a zero-based index: 0 -> A, 25 -> Z, 26 -> AA.
String _columnName(int index) {
  var i = index;
  var name = '';
  while (true) {
    name = '${String.fromCharCode(65 + i % 26)}$name';
    i = i ~/ 26 - 1;
    if (i < 0) break;
  }
  return name;
}

/// Escapes XML text content (`&`, `<`, `>`).
String _text(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Escapes an XML attribute value (text plus quotes).
String _attr(String value) =>
    _text(value).replaceAll('"', '&quot;').replaceAll("'", '&apos;');
