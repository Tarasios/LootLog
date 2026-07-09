/// Tests the tiny pure-Dart xlsx writer: a decodable zip of the expected OOXML
/// parts, with numbers carried as verbatim decimal literals (never floats).
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:duobudget/data/export/xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

String _entry(Archive archive, String name) {
  final file = archive.findFile(name);
  expect(file, isNotNull, reason: 'missing $name');
  return utf8.decode(file!.content as List<int>);
}

void main() {
  final workbook = XlsxWorkbook([
    XlsxSheet(
      name: 'First',
      header: const ['Label', 'Amount'],
      rows: [
        [const XlsxCell.text('Coffee & tea <x>'), const XlsxCell.number('12.34')],
        [const XlsxCell.text('Refund'), const XlsxCell.number('-0.05')],
      ],
    ),
    const XlsxSheet(name: 'Second', header: ['Only'], rows: []),
  ]);

  test('encodes a decodable zip with all required OOXML parts', () {
    final bytes = encodeXlsx(workbook);
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, containsAll(<String>[
      '[Content_Types].xml',
      '_rels/.rels',
      'xl/workbook.xml',
      'xl/_rels/workbook.xml.rels',
      'xl/styles.xml',
      'xl/worksheets/sheet1.xml',
      'xl/worksheets/sheet2.xml',
    ]));
  });

  test('content types and workbook declare one part per sheet', () {
    final archive = ZipDecoder().decodeBytes(encodeXlsx(workbook));
    final ct = _entry(archive, '[Content_Types].xml');
    expect('sheet1.xml'.allMatches(ct).length, 1);
    expect('sheet2.xml'.allMatches(ct).length, 1);

    final wb = _entry(archive, 'xl/workbook.xml');
    expect(wb, contains('name="First"'));
    expect(wb, contains('name="Second"'));
    expect(wb, contains('r:id="rId1"'));
    expect(wb, contains('r:id="rId2"'));

    final rels = _entry(archive, 'xl/_rels/workbook.xml.rels');
    // Two worksheet relationships plus the styles relationship (rId3).
    expect(rels, contains('worksheets/sheet1.xml'));
    expect(rels, contains('worksheets/sheet2.xml'));
    expect(rels, contains('styles.xml'));
  });

  test('numbers are written as verbatim decimal literals, never floats', () {
    final archive = ZipDecoder().decodeBytes(encodeXlsx(workbook));
    final sheet1 = _entry(archive, 'xl/worksheets/sheet1.xml');
    expect(sheet1, contains('<v>12.34</v>'));
    expect(sheet1, contains('<v>-0.05</v>'));
    // Numeric cells carry no inlineStr wrapper.
    expect(sheet1, isNot(contains('<is><t xml:space="preserve">12.34')));
  });

  test('text is XML-escaped and the header row is styled bold', () {
    final archive = ZipDecoder().decodeBytes(encodeXlsx(workbook));
    final sheet1 = _entry(archive, 'xl/worksheets/sheet1.xml');
    expect(sheet1, contains('Coffee &amp; tea &lt;x&gt;'));
    // Header cells use style 1 (bold).
    expect(sheet1, contains('<c r="A1" s="1" t="inlineStr">'));
  });

  test('deterministic: same workbook encodes to identical bytes', () {
    expect(encodeXlsx(workbook), encodeXlsx(workbook));
  });

  test('columns past Z get spreadsheet-style two-letter refs', () {
    final wide = XlsxWorkbook([
      XlsxSheet(
        name: 'Wide',
        header: List.generate(28, (i) => 'C$i'),
        rows: const [],
      ),
    ]);
    final archive = ZipDecoder().decodeBytes(encodeXlsx(wide));
    final sheet = _entry(archive, 'xl/worksheets/sheet1.xml');
    expect(sheet, contains('r="Z1"'));
    expect(sheet, contains('r="AA1"'));
    expect(sheet, contains('r="AB1"'));
  });
}
