import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/settings_screen.dart';

/// A fake FilePicker substituted via FilePicker.platform (a mutable static field — the same
/// dependency-injection style already used for http.Client elsewhere in this codebase), so
/// saveFile() can be exercised without touching the real platform channel.
class _FakeFilePicker extends FilePicker {
  String? lastFileName;
  Uint8List? lastBytes;
  String? returnPath;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    lastFileName = fileName;
    lastBytes = bytes;
    return returnPath;
  }
}

/// Adds a "Save to device" delivery path (via file_picker's saveFile — Android's Storage Access
/// Framework) alongside the existing share-sheet export, since the share sheet's available targets
/// depend on what's installed and don't reliably include a local-save option on every device.
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;
  late _FakeFilePicker fakePicker;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
    // FilePicker.platform's backing field is never initialized outside a real app (no plugin
    // registration happens in a widget test), so there's nothing to read-and-restore — just set
    // the fake. Each test file runs in its own isolated VM, so this can't leak across files.
    fakePicker = _FakeFilePicker();
    FilePicker.platform = fakePicker;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repo: repo)));
    await tester.pumpAndSettle();
  }

  testWidgets('Export offers both Share and Save to device', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Export (JSON backup)'));
    await tester.pumpAndSettle();

    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Save to device'), findsOneWidget);
  });

  testWidgets('Save to device writes the export bytes via file_picker and confirms',
      (tester) async {
    fakePicker.returnPath = '/tree/primary/Documents/megrim-export.json';
    await pumpSettings(tester);

    await tester.tap(find.text('Export (JSON backup)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to device'));
    await tester.pumpAndSettle();

    expect(fakePicker.lastFileName, matches(r'^megrim-export-\d{8}\.json$'));
    final written = utf8.decode(fakePicker.lastBytes!);
    expect(written, contains('"format": "megrim-export"'));
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('Cancelling the save dialog shows no confirmation', (tester) async {
    fakePicker.returnPath = null; // user cancelled the native save dialog
    await pumpSettings(tester);

    await tester.tap(find.text('Export (CSV)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to device'));
    await tester.pumpAndSettle();

    expect(fakePicker.lastFileName, matches(r'^megrim-export-\d{8}\.csv$'));
    expect(find.text('Saved.'), findsNothing);
  });
}
