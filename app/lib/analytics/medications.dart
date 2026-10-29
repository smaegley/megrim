import '../database/database.dart' show MedClass;
import '../models/event_time.dart' show wallDate;
import '../models/med_entry.dart';
import '../models/medications.dart';
import '../models/relief_entry.dart';

export '../models/medications.dart' show kMixedClasses, kUnclassified;

/// Acute-medication days and the overuse notice (backlog #18), and the "what helped" table
/// (backlog #19). Pure functions over events; the dashboard calls them.


/// One event's medication and relief fields, in the zone it was logged in.
class MedEventInput {
  final DateTime startedAt;
  final int? startOffsetMin;
  final List<MedEntry> meds;
  final List<ReliefEntry> relief;
  const MedEventInput({
    required this.startedAt,
    this.startOffsetMin,
    this.meds = const [],
    this.relief = const [],
  });
}

/// Medication days in one calendar month.
class MedMonth {
  final int year;
  final int month;

  /// Distinct days with any acute medication, classified or not.
  final int days;

  /// Distinct days per class ([kUnclassified] included), only classes with at least one day.
  final Map<String, int> byClass;

  /// Distinct days with any of the overuse classes (the ICHD-3 8.2.6 total).
  final int overuseClassDays;

  /// Why this month reached a reference level: classes at their own level, else [kMixedClasses];
  /// empty when it didn't.
  final List<String> levelsReached;

  const MedMonth(
    this.year,
    this.month, {
    required this.days,
    this.byClass = const {},
    this.overuseClassDays = 0,
    this.levelsReached = const [],
  });

  String get key => '$year-${month.toString().padLeft(2, '0')}';
  bool get reachedLevel => levelsReached.isNotEmpty;
}

class MedicationDays {
  /// Distinct days with any acute medication in the last 30 days (today and the 29 before).
  final int last30;

  /// Distinct days per class in the last 30 days, in [MedClass.all] order then [kUnclassified],
  /// only classes with at least one day.
  final Map<String, int> byClassLast30;

  /// Every month from the first medication through the current one, oldest first.
  final List<MedMonth> byMonth;

  /// The last [kOveruseMonths] complete months, when each reached a level; otherwise null. A
  /// plain count over the last 30 days never raises it.
  final List<MedMonth>? notice;

  /// Medication names on entries that have no class, alphabetical: the card asks for them.
  final List<String> unclassifiedNames;

  const MedicationDays({
    required this.last30,
    this.byClassLast30 = const {},
    this.byMonth = const [],
    this.notice,
    this.unclassifiedNames = const [],
  });
}

/// The class of [name], matched exactly and then ignoring case and surrounding spaces.
String? classOf(String name, Map<String, String> classes) {
  final exact = classes[name];
  if (exact != null) return exact;
  final key = name.trim().toLowerCase();
  for (final MapEntry(key: n, value: c) in classes.entries) {
    if (n.trim().toLowerCase() == key) return c;
  }
  return null;
}

/// The local day a dose belongs to: its own time when recorded (stored as UTC, read in the
/// event's zone), else the event's start day.
DateTime doseDay(MedEntry m, DateTime startedAt, int? startOffsetMin) {
  final t = m.time == null ? null : DateTime.tryParse(m.time!);
  return wallDate(t ?? startedAt, startOffsetMin);
}

/// One reason [m] reached a reference level, with its count and the level:
/// "Triptan on 11 days (level 10)".
String levelReason(MedMonth m, String reason) => reason == kMixedClasses
    ? 'A mix of classes on ${m.overuseClassDays} days in total (level $kMixedOveruseDaysPerMonth)'
    : '${kMedClassLabels[reason]} on ${m.byClass[reason]} days '
          '(level ${kOveruseDaysPerMonth[reason]})';

int _monthIndex(DateTime d) => d.year * 12 + d.month - 1;

/// [classes] maps medication names to [MedClass] values. Null when no entry has a medication.
MedicationDays? medicationDays(
  Iterable<MedEventInput> events,
  Map<String, String> classes,
  DateTime now,
) {
  // Day sets per class, so two doses on one day (or across two entries) count once.
  final daysByClass = <String, Set<DateTime>>{};
  final unclassified = <String>{};
  for (final e in events) {
    for (final m in e.meds) {
      if (m.name.trim().isEmpty) continue;
      final cls = classOf(m.name, classes);
      if (cls == null) unclassified.add(m.name.trim());
      daysByClass
          .putIfAbsent(cls ?? kUnclassified, () => <DateTime>{})
          .add(doseDay(m, e.startedAt, e.startOffsetMin));
    }
  }
  if (daysByClass.isEmpty) return null;

  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final from30 = DateTime(today.year, today.month, today.day - 29);
  bool in30(DateTime d) => !d.isBefore(from30) && !d.isAfter(today);

  final order = [...MedClass.all, kUnclassified];
  final allDays = {for (final s in daysByClass.values) ...s};
  final byClassLast30 = <String, int>{};
  for (final c in order) {
    final n = daysByClass[c]?.where(in30).length ?? 0;
    if (n > 0) byClassLast30[c] = n;
  }

  final first = allDays.map(_monthIndex).reduce((a, b) => a < b ? a : b);
  final last = [_monthIndex(today), ...allDays.map(_monthIndex)].reduce((a, b) => a > b ? a : b);
  final byMonth = [for (var m = first; m <= last; m++) _month(m, daysByClass, order)];

  List<MedMonth>? notice;
  final current = _monthIndex(today);
  final complete = byMonth.where((m) => _monthIndex(DateTime(m.year, m.month)) < current).toList();
  if (complete.length >= kOveruseMonths) {
    final recent = complete.sublist(complete.length - kOveruseMonths);
    // Consecutive by construction (byMonth has no gaps), and ending with last month.
    if (_monthIndex(DateTime(recent.last.year, recent.last.month)) == current - 1 &&
        recent.every((m) => m.reachedLevel)) {
      notice = recent;
    }
  }

  return MedicationDays(
    last30: allDays.where(in30).length,
    byClassLast30: byClassLast30,
    byMonth: byMonth,
    notice: notice,
    unclassifiedNames: unclassified.toList()..sort(),
  );
}

MedMonth _month(int index, Map<String, Set<DateTime>> daysByClass, List<String> order) {
  bool inMonth(DateTime d) => _monthIndex(d) == index;
  final byClass = <String, int>{};
  final any = <DateTime>{};
  final overuse = <DateTime>{};
  for (final c in order) {
    final days = daysByClass[c]?.where(inMonth).toSet() ?? const <DateTime>{};
    if (days.isEmpty) continue;
    byClass[c] = days.length;
    any.addAll(days);
    if (isOveruseClass(c)) overuse.addAll(days);
  }
  final levels = [
    for (final MapEntry(key: c, value: limit) in kOveruseDaysPerMonth.entries)
      if ((byClass[c] ?? 0) >= limit) c,
  ];
  // ICHD-3 8.2.6 applies only when no class reaches its own level, and needs a mix: one class
  // under its own level (say simple pain relievers on 12 days) is not overuse.
  final classesUsed = byClass.keys.where(isOveruseClass).length;
  if (levels.isEmpty && classesUsed >= 2 && overuse.length >= kMixedOveruseDaysPerMonth) {
    levels.add(kMixedClasses);
  }
  return MedMonth(
    index ~/ 12,
    index % 12 + 1,
    days: any.length,
    byClass: byClass,
    overuseClassDays: overuse.length,
    levelsReached: levels,
  );
}

/// One medication or relief method in the "what helped" table.
class HelpedRow {
  final String name;

  /// True for a non-drug relief method, false for a medication.
  final bool relief;

  /// Times recorded on entries (each dose or each recorded try).
  final int tried;
  final int helped;
  final int notHelped;

  const HelpedRow({
    required this.name,
    required this.relief,
    required this.tried,
    required this.helped,
    required this.notHelped,
  });

  /// Tries with no answer to "helped?".
  int get unknown => tried - helped - notHelped;

  /// Share that helped among the tries with an answer, 0–100; null when none has one. Unknowns
  /// are left out rather than counted as "didn't help".
  int? get helpedPct =>
      helped + notHelped == 0 ? null : (helped * 100 / (helped + notHelped)).round();
}

/// Medications and relief methods, most-tried first (ties alphabetical, medications first).
/// Names are grouped ignoring case and surrounding spaces, shown as first written. Empty when
/// nothing is recorded.
List<HelpedRow> whatHelped(Iterable<MedEventInput> events) {
  final rows = <(bool, String), ({String name, int tried, int helped, int not})>{};
  void add(bool relief, String name, bool? helped) {
    final n = name.trim();
    if (n.isEmpty) return;
    final key = (relief, n.toLowerCase());
    final r = rows[key] ?? (name: n, tried: 0, helped: 0, not: 0);
    rows[key] = (
      name: r.name,
      tried: r.tried + 1,
      helped: r.helped + (helped == true ? 1 : 0),
      not: r.not + (helped == false ? 1 : 0),
    );
  }

  for (final e in events) {
    for (final m in e.meds) {
      add(false, m.name, m.helped);
    }
    for (final r in e.relief) {
      add(true, r.name, r.helped);
    }
  }
  final out =
      [
        for (final MapEntry(key: (relief, _), value: r) in rows.entries)
          HelpedRow(
            name: r.name,
            relief: relief,
            tried: r.tried,
            helped: r.helped,
            notHelped: r.not,
          ),
      ]..sort((a, b) {
        final byTried = b.tried.compareTo(a.tried);
        if (byTried != 0) return byTried;
        if (a.relief != b.relief) return a.relief ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  return out;
}
