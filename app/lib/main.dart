import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;

import 'app.dart';
import 'database/database.dart';
import 'repositories/megrim_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Date and number names for every locale (docs/TRANSLATIONS.md), so code outside the widget tree
  // (the PDF report, notifications, chart labels) can format in the app's language.
  await initializeDateFormatting();
  // Register Megrim's own GPL-3.0 licence so it appears on the built-in licences page (About →
  // View licences) alongside the auto-collected third-party package licences.
  LicenseRegistry.addLicense(() async* {
    final gpl = await rootBundle.loadString('assets/gpl-3.0.txt');
    yield LicenseEntryWithLineBreaks(
      const ['Megrim'],
      'Megrim — Copyright (C) 2026 the Megrim authors.\n'
      'Licensed under the GNU General Public License v3.0 or later.\n\n$gpl',
    );
  });
  // The PDF report embeds Noto Sans (Latin/Greek/Cyrillic), bundled unmodified from upstream. Pub
  // package licences are collected automatically; a bundled asset's is not, so register it here.
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Noto Sans'], ofl);
  });
  final db = MegrimDatabase();
  final repo = MegrimRepository(db: db);
  runApp(MegrimApp(repo: repo));
}
