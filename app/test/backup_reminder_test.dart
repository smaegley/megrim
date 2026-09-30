import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/backup_status.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/quick_log_screen.dart';
import 'package:megrim/screens/settings_screen.dart';

/// Backlog #14: a backup *reminder*, opt-in, with no background work and no new permissions.
void main() {
  group('BackupStatus', () {
    final now = DateTime(2026, 9, 30, 10);
    BackupStatus at(DateTime? last, {int days = 30}) =>
        BackupStatus.from(lastBackupAt: last, reminderDays: days, now: now);

    test('age reads in calendar days, not elapsed hours', () {
      // 23:30 yesterday is "Yesterday" even though it is under 24 hours ago.
      expect(at(DateTime(2026, 9, 29, 23, 30)).ageLabel, 'Yesterday');
      expect(at(DateTime(2026, 9, 30, 0, 5)).ageLabel, 'Today');
      expect(at(DateTime(2026, 9, 18)).ageLabel, '12 days ago');
      expect(at(null).ageLabel, 'Never');
    });

    test('a future date reads as today rather than a negative age', () {
      final s = at(DateTime(2026, 10, 5));
      expect(s.daysSince, 0);
      expect(s.ageLabel, 'Today');
      expect(s.isOverdue, isFalse);
    });

    test('overdue needs the reminder on, and never-backed-up counts as overdue', () {
      expect(at(DateTime(2026, 9, 18)).isOverdue, isFalse); // 12 days, interval 30
      expect(at(DateTime(2026, 8, 1)).isOverdue, isTrue);
      expect(at(null).isOverdue, isTrue, reason: 'never backed up is the case worth surfacing');
      // Off: no overdue state at all, however old.
      expect(at(DateTime(2020, 1, 1), days: kBackupReminderOff).isOverdue, isFalse);
      expect(at(null, days: kBackupReminderOff).isOverdue, isFalse);
      expect(at(null, days: kBackupReminderOff).reminderEnabled, isFalse);
    });

    test('the interval boundary is inclusive: exactly N days is due', () {
      // `now` is 30 Sep 2026, so 31 Aug is exactly 30 days back and 1 Sep is 29.
      expect(at(DateTime(2026, 8, 31)).daysSince, 30);
      expect(at(DateTime(2026, 9, 1)).daysSince, 29);

      expect(at(DateTime(2026, 8, 31), days: 30).isOverdue, isTrue, reason: '30 >= 30');
      expect(at(DateTime(2026, 9, 1), days: 30).isOverdue, isFalse, reason: '29 < 30');
      expect(at(DateTime(2026, 9, 1), days: 29).isOverdue, isTrue, reason: '29 >= 29');
    });

    test('labels', () {
      expect(backupReminderLabel(kBackupReminderOff), 'Off');
      expect(backupReminderLabel(30), 'Every 30 days');
    });
  });

  group('repository', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    test('defaults: never backed up, reminder off', () async {
      expect(await repo.lastBackupAt, isNull);
      expect(await repo.backupReminderDays, kBackupReminderOff);
      final s = await repo.backupStatus();
      expect(s.neverBackedUp, isTrue);
      expect(s.reminderEnabled, isFalse);
      expect(s.isOverdue, isFalse, reason: 'an upgrade must not start nagging');
    });

    test('markBackedUp and the interval round-trip', () async {
      final when = DateTime.utc(2026, 9, 20, 8);
      await repo.markBackedUp(when);
      await repo.setBackupReminderDays(7);
      expect((await repo.lastBackupAt)!.toUtc(), when);
      expect(await repo.backupReminderDays, 7);
      final s = await repo.backupStatus(now: DateTime(2026, 9, 30));
      expect(s.reminderEnabled, isTrue);
      expect(s.isOverdue, isTrue); // 10 days > 7
    });
  });

  group('UI', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    testWidgets('Settings shows the last backup and changes the interval', (t) async {
      await t.pumpWidget(MaterialApp(home: SettingsScreen(repo: repo)));
      await t.pumpAndSettle();

      expect(find.text('Last backup'), findsOneWidget);
      expect(find.textContaining('Never · Off'), findsOneWidget);

      await t.tap(find.text('Last backup'));
      await t.pumpAndSettle();
      expect(find.text('Remind me to back up'), findsOneWidget);
      await t.tap(find.text('Every 30 days'));
      await t.pumpAndSettle();

      expect(await repo.backupReminderDays, 30);
      // Never backed up + reminder on = due.
      expect(find.textContaining('Never · Every 30 days · due'), findsOneWidget);
    });

    testWidgets('the Log line is hidden until the reminder is on', (t) async {
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pumpAndSettle();
      expect(find.textContaining('Last backup:'), findsNothing);

      await repo.setBackupReminderDays(30);
      await t.pumpWidget(MaterialApp(
          home: QuickLogScreen(repo: repo, refreshToken: 1)));
      await t.pumpAndSettle();
      expect(find.text('Last backup: Never'), findsOneWidget);
    });

    testWidgets('tapping the Log line calls back to open Settings', (t) async {
      await repo.setBackupReminderDays(30);
      var opened = false;
      await t.pumpWidget(MaterialApp(
        home: QuickLogScreen(repo: repo, onOpenSettings: () => opened = true),
      ));
      await t.pumpAndSettle();
      await t.tap(find.text('Last backup: Never'));
      await t.pump();
      expect(opened, isTrue);
    });
  });
}
