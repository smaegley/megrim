/// Backup-reminder state (backlog #14): how long since the user last exported, and whether that is
/// long enough to say so.
///
/// Deliberately a *reminder*, not automation. Automatic backups would need persistent access to a
/// user-chosen folder plus a background scheduler, which on Android means extra manifest
/// permissions (against the app's INTERNET-only guarantee) and on iOS is not reliably possible at
/// all — see backlog #15. Pure, with no I/O and no clock of its own, so it tests directly.
library;

/// Reminder intervals offered in Settings, in days. 0 = off, and is the default: the reminder is
/// opt-in, so an upgrade changes nothing until the user chooses an interval.
const List<int> kBackupReminderChoices = [0, 7, 14, 30, 90];
const int kBackupReminderOff = 0;

class BackupStatus {
  /// When the user last completed a JSON export (UTC), or null if they never have — which includes
  /// everyone who exported before this feature existed. That self-corrects on their next export.
  final DateTime? lastBackupAt;

  /// Reminder interval in days; [kBackupReminderOff] disables the overdue state entirely.
  final int reminderDays;

  /// Whole days between the last backup's local date and today's; null when there is no backup.
  final int? daysSince;

  const BackupStatus({
    required this.lastBackupAt,
    required this.reminderDays,
    required this.daysSince,
  });

  factory BackupStatus.from({
    required DateTime? lastBackupAt,
    required int reminderDays,
    required DateTime now,
  }) {
    int? days;
    if (lastBackupAt != null) {
      final a = lastBackupAt.toLocal();
      final b = now.toLocal();
      // Compare calendar dates, not elapsed hours, so "yesterday evening" reads as 1 day and not
      // 0. UTC-normalised midnights keep a DST shift from moving the answer (the cb6671c bug
      // class).
      days = DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;
      // A backup dated in the future (a clock change, or a restored device) would otherwise read
      // as a negative age; call it today rather than showing nonsense.
      if (days < 0) days = 0;
    }
    return BackupStatus(
      lastBackupAt: lastBackupAt,
      reminderDays: reminderDays,
      daysSince: days,
    );
  }

  bool get neverBackedUp => lastBackupAt == null;

  /// Whether the user asked to be reminded at all. The last-backup date is shown either way; only
  /// the warning state and the Log-screen line are gated on this.
  bool get reminderEnabled => reminderDays > kBackupReminderOff;

  /// True when reminding is on and the last backup is older than the interval. Never having backed
  /// up counts as overdue — it is the case most worth surfacing.
  bool get isOverdue {
    if (!reminderEnabled) return false;
    return daysSince == null || daysSince! >= reminderDays;
  }

  /// "Never" / "Today" / "Yesterday" / "12 days ago".
  String get ageLabel {
    final d = daysSince;
    if (d == null) return 'Never';
    if (d == 0) return 'Today';
    if (d == 1) return 'Yesterday';
    return '$d days ago';
  }
}

/// "Off" / "Every 30 days", for the Settings subtitle and the interval picker.
String backupReminderLabel(int days) =>
    days <= kBackupReminderOff ? 'Off' : 'Every $days days';
