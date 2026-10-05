import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/import_service.dart';
import 'package:megrim/services/report_content.dart';
import 'package:megrim/services/report_pdf.dart';
import 'package:pdf/pdf.dart' show TtfParser;

/// Backlog #12. The content layer is asserted in report_content_test.dart; this checks the thing
/// actually renders, including with text the font cannot draw.
ByteData _font(String name) =>
    File('assets/fonts/$name').readAsBytesSync().buffer.asByteData();

void main() {
  late ByteData regular;
  late ByteData bold;
  late bool Function(int) canRender;

  setUpAll(() {
    regular = _font('NotoSans-Regular.ttf');
    bold = _font('NotoSans-Bold.ttf');
    canRender = TtfParser(regular).charToGlyphIndexMap.containsKey;
  });

  test('the bundled font covers the app\'s own labels and European scripts', () {
    // These come from the app's own bucket names and from European notes, and are exactly what
    // the PDF built-in fonts cannot draw — the reason a font is bundled at all.
    for (final s in ['Δ', '–', '·', 'ł', 'ş', 'ğ', 'Α', 'П', 'é', 'ü']) {
      expect(canRender(s.runes.first), isTrue, reason: 'font must cover "$s"');
    }
    // Two known gaps, handled differently and deliberately: a readable stand-in for the symbol
    // the app's own "≥ 14 h" label uses, and a visible "?" for anything genuinely unrenderable.
    expect(canRender('≥'.runes.first), isFalse);
    expect(sanitiseForFont('≥ 14 h', canRender).text, '>= 14 h');
    expect(sanitiseForFont('≥ 14 h', canRender).substituted, isFalse,
        reason: 'a faithful stand-in is not a lost character');
    expect(canRender('頭'.runes.first), isFalse);
    expect(sanitiseForFont('頭', canRender).substituted, isTrue);
  });

  test('bar widths are proportional and safe at the edges', () {
    expect(filledFlex(0, 10), 0);
    expect(filledFlex(5, 10), 500);
    expect(filledFlex(10, 10), 1000);
    expect(filledFlex(3, 0), 0, reason: 'an all-zero chart must not divide by zero');
  });

  group('rendering', () {
    late MegrimDatabase db;
    late MegrimRepository repo;

    setUp(() async {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    Future<Uint8List> render() async => renderReportPdf(
          await repo.reportContent(
              now: DateTime(2026, 10, 5), canRender: canRender),
          regular: regular,
          bold: bold,
        );

    test('an empty diary still produces a valid PDF', () async {
      final bytes = await render();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('the full sample diary renders, and is substantially bigger', () async {
      await ImportService(db).importJsonString(
          File('test/fixtures/sample-data.json').readAsStringSync(),
          replace: true);
      final bytes = await render();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // 55 entries plus factor tables; an empty diary is a few KB.
      expect(bytes.length, greaterThan(20000));
    });

    test('notes the font cannot draw render without throwing', () async {
      await ImportService(db).importJsonString('''
{"format":"megrim-export","format_version":1,"events":[
 {"id":"a","started_at":"2026-01-01T12:00:00Z","notes":"頭痛がひどい","severity":7},
 {"id":"b","started_at":"2026-01-02T12:00:00Z","notes":"Łódź, ból głowy","severity":4}]}''',
          replace: true);
      final content = await repo.reportContent(
          now: DateTime(2026, 10, 5), canRender: canRender);
      // Japanese substituted and flagged; Polish kept intact.
      expect(content.events.map((e) => e.notes), contains('??????'));
      expect(content.events.map((e) => e.notes), contains('Łódź, ból głowy'));
      expect(content.footnotes.first, contains('could not be drawn'));

      final bytes = await renderReportPdf(content, regular: regular, bold: bold);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
