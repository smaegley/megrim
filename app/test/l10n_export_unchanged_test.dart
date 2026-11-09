import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';

import '../integration_test/shots.dart';

/// The export is never localized (docs/TRANSLATIONS.md): stored values, keys, analytics labels,
/// reasons and caveats stay English, so a file moves between phones in any language and the
/// import format doesn't change. Same data, phones in different languages, identical files
/// apart from the times rows were written.
void main() {
  // Wall-clock times of the seeding and enrichment runs, which differ between runs anyway.
  final writtenAt = RegExp(r'"(created_at|updated_at|enriched_at)": "[^"]*"');
  String masked(String json) => json.replaceAllMapped(writtenAt, (m) => '"${m[1]}": "…"');

  testWidgets('the JSON and CSV exports are the same whatever the phone language', (tester) async {
    final now = DateTime(2026, 11, 9, 12);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    Future<(String, String)> exportUnder(List<Locale> locales) async {
      tester.platformDispatcher.localesTestValue = locales;
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      final repo = MegrimRepository(db: db);
      try {
        return await tester.runAsync(() async {
          await seedDemo(db, repo, now);
          return (
            masked(await repo.exportJson(now: now.toUtc())),
            await repo.exporter.toCsv(),
          );
        }) as (String, String);
      } finally {
        await tester.runAsync(db.close);
      }
    }

    final english = await exportUnder(const [Locale('en', 'US')]);
    for (final locales in const [
      [Locale('fr', 'FR')],
      [Locale('zh', 'CN'), Locale('de', 'DE')],
    ]) {
      final other = await exportUnder(locales);
      expect(other.$1, english.$1, reason: 'JSON under $locales');
      expect(other.$2, english.$2, reason: 'CSV under $locales');
    }
    expect(english.$1, contains('"Nausea"'), reason: 'the demo data should include a default symptom');
  });
}
