import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app.dart';
import 'database/database.dart';
import 'repositories/megrim_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  final db = MegrimDatabase();
  final repo = MegrimRepository(db: db);
  runApp(MegrimApp(repo: repo));
}
