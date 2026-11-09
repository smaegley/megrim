import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/l10n/data_labels.dart';
import 'package:megrim/l10n/l10n.dart';
import 'package:megrim/repositories/megrim_repository.dart';

import '../integration_test/shots.dart';

/// Finds text that's still hard-coded in English (docs/TRANSLATIONS.md, phase 1).
///
/// Runs the store-screenshot flow in the en-XA pseudo-locale, where every message reads
/// ⟦Àçççéñtéd⟧ (`tools/l10n.py pseudo` writes it; CI does so before `flutter pub get`). Any
/// English word left on screen outside ⟦…⟧ didn't come from a message, unless it's the demo
/// data's own text (what a user typed) or an English date name (intl has no en-XA data).
void main() {
  const pseudo = Locale('en', 'XA');
  final hasPseudo = AppLocalizations.supportedLocales.contains(pseudo);

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['none'],
    );
  });

  testWidgets('no English text outside messages on the screenshot screens', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [pseudo];

    final now = DateTime.now();
    final allowed = _allowedWords(demoExportJson(now));
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    await tester.runAsync(() => seedDemo(db, repo, now));

    await tester.pumpWidget(demoApp(repo, supportedLocales: const [Locale('en'), pseudo]));
    await settle(tester);
    final found = <String>{};
    await runShots(
      tester,
      (shot) async {
        for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
          final text = w.text.toPlainText();
          final words = _stray(text).where((word) => !allowed.contains(word.toLowerCase()));
          if (words.isNotEmpty) found.add('$shot: "$text"');
        }
      },
      setBrightness: (b) {
        if (b == null) {
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        } else {
          tester.platformDispatcher.platformBrightnessTestValue = b;
        }
      },
    );
    expect(found, isEmpty, reason: 'text shown outside a message (hard-coded?):\n${found.join('\n')}');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => db.close());
  }, skip: !hasPseudo); // locally: tools/l10n.py pseudo, then flutter pub get
}

/// Words of two or more Latin letters outside the ⟦…⟧ of pseudo messages (which can nest: a
/// message placed inside another).
Iterable<String> _stray(String text) {
  final innermost = RegExp(r'⟦[^⟦⟧]*⟧');
  var rest = text;
  while (innermost.hasMatch(rest)) {
    rest = rest.replaceAll(innermost, ' ');
  }
  return RegExp(r'[A-Za-z]{2,}').allMatches(rest).map((m) => m[0]!);
}

/// What may legitimately show in English: the demo data's text, except the default values the
/// app translates (a missed dataLabel() must still be caught), and English date names.
Set<String> _allowedWords(String demoJson) {
  final translated = kTranslatedDataValues.toSet();
  final words = <String>{};
  void walk(Object? v) {
    if (v is String && !translated.contains(v)) {
      words.addAll(RegExp(r'[A-Za-z]{2,}').allMatches(v).map((m) => m[0]!.toLowerCase()));
    } else if (v is Map) {
      v.values.forEach(walk);
    } else if (v is List) {
      v.forEach(walk);
    }
  }

  walk(jsonDecode(demoJson));
  final s = DateFormat('', 'en').dateSymbols;
  for (final name in [...s.MONTHS, ...s.SHORTMONTHS, ...s.WEEKDAYS, ...s.SHORTWEEKDAYS, ...s.AMPMS]) {
    words.add(name.toLowerCase());
  }
  return words;
}
