import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../repositories/megrim_repository.dart';
import '../widgets/severity_badge.dart';
import 'event_detail_screen.dart';

/// History (SPEC §4.3): a persistent List | Calendar segmented picker, a severity badge on each
/// row, swipe-to-delete with Snackbar undo, and a manual "add past entry" action so a migraine
/// that couldn't be logged live can be recreated after the fact (review items #2, #3, #4).
class HistoryScreen extends StatefulWidget {
  final MegrimRepository repo;

  /// Test seam: pins the Calendar's "today" (month range end + today ring) so widget tests aren't
  /// coupled to the real clock. Production always leaves this null.
  @visibleForTesting
  final DateTime? todayOverride;
  const HistoryScreen({super.key, required this.repo, this.todayOverride});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum _HistoryView { list, calendar }

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryView _view = _HistoryView.list;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add),
        label: const Text('Add past entry'),
        tooltip: 'Log a migraine that happened earlier',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_HistoryView>(
                segments: const [
                  ButtonSegment(
                    value: _HistoryView.list,
                    icon: Icon(Icons.list),
                    label: Text('List'),
                  ),
                  ButtonSegment(
                    value: _HistoryView.calendar,
                    icon: Icon(Icons.calendar_month),
                    label: Text('Calendar'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MigraineEvent>>(
              stream: widget.repo.watchEvents(),
              builder: (context, snap) {
                final events = snap.data ?? const [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // List has nothing to show with zero events, but Calendar still shows the
                // current month's grid (all grey) so a first entry can be created by tapping a
                // date — the empty state shouldn't disable the tap-to-add flow just introduced.
                if (events.isEmpty && _view == _HistoryView.list) {
                  return const Center(child: Text('No migraines logged yet.'));
                }
                return _view == _HistoryView.calendar
                    ? _CalendarView(
                        events: events,
                        onDayTap: _onCalendarDayTap,
                        today: widget.todayOverride ?? DateTime.now(),
                      )
                    : _listView(events);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _listView(List<MigraineEvent> events) {
    final df = DateFormat('EEE d MMM yyyy, HH:mm');
    return ListView.separated(
      // Room so the FAB doesn't cover the last row.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = events[i];
        // Calendar days covered, so a migraine that runs overnight or longer is visible as
        // multi-day right in the list (backlog #10).
        final spanDays = localDaysSpanned(e).length;
        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          onDismissed: (_) => _delete(e.id),
          child: ListTile(
            leading: SeverityBadge(severity: e.severity),
            title: Text(df.format(e.startedAt.toLocal())),
            subtitle: Text(
              [
                if (e.severity != null) 'Severity ${e.severity}/10',
                if (spanDays > 1) '$spanDays days',
                if (e.endedAt == null) 'ongoing',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    EventDetailScreen(repo: widget.repo, eventId: e.id),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addManual() async {
    final home = await widget.repo.homeLocation;
    final id = await widget.repo.startEvent(
      lat: home?.lat,
      lon: home?.lon,
      label: home?.label,
    );
    // End it immediately so a past entry isn't picked up as the live "in-progress" migraine by
    // Quick Log; the user then sets the real start/end in the editor.
    await widget.repo.endEvent(id);
    if (!mounted) return;
    // Open the detail editor so the user can set the real start/end time and details.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(repo: widget.repo, eventId: id),
      ),
    );
  }

  /// Calendar day tap (backlog #9): exactly one entry that day opens it directly; several offer a
  /// picker to choose which one; none starts a new past entry pre-dated to the tapped day (instead
  /// of "now" — the whole point of tapping a specific day rather than using the FAB).
  Future<void> _onCalendarDayTap(
    DateTime localDay,
    List<MigraineEvent> dayEvents,
  ) async {
    if (dayEvents.isEmpty) {
      await _addManualForDate(localDay);
      return;
    }
    if (dayEvents.length == 1) {
      await _openEvent(dayEvents.single.id);
      return;
    }
    final sorted = [...dayEvents]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final chosenId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${dayEvents.length} entries on '
                '${DateFormat('EEE d MMM yyyy').format(localDay)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final e in sorted)
              ListTile(
                leading: SeverityBadge(severity: e.severity),
                title: Text(DateFormat('HH:mm').format(e.startedAt.toLocal())),
                subtitle: Text(
                  [
                    if (e.severity != null) 'Severity ${e.severity}/10',
                    if (e.endedAt == null) 'ongoing',
                  ].join(' · '),
                ),
                onTap: () => Navigator.pop(context, e.id),
              ),
          ],
        ),
      ),
    );
    if (chosenId != null) await _openEvent(chosenId);
  }

  Future<void> _addManualForDate(DateTime localDay) async {
    final home = await widget.repo.homeLocation;
    final id = await widget.repo.startEvent(
      lat: home?.lat,
      lon: home?.lon,
      label: home?.label,
    );
    await widget.repo.endEvent(id);
    // Pre-fill the tapped day (noon local, an arbitrary but unbiased time-of-day) instead of
    // leaving it at "now" — saves the manual date edit the FAB's "Add past entry" still needs.
    final at = DateTime(
      localDay.year,
      localDay.month,
      localDay.day,
      12,
    ).toUtc();
    await widget.repo.updateEvent(
      MigraineEventsCompanion(
        id: Value(id),
        startedAt: Value(at),
        endedAt: Value(at),
      ),
    );
    await _openEvent(id);
  }

  Future<void> _openEvent(String id) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(repo: widget.repo, eventId: id),
      ),
    );
  }

  Future<void> _delete(String id) async {
    final removed = await widget.repo.deleteEvent(id);
    if (removed == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              widget.repo.restoreEvent(removed.event, removed.derived),
        ),
      ),
    );
  }
}

/// Every local calendar day [e] covers, start date through end date inclusive (backlog #10 — a
/// multi-day migraine shows on each day it spans, not just its start day). An ongoing event (no
/// end yet) or a malformed end-before-start covers only its start day. Days are built with
/// constructor normalisation (`day + i`) rather than `.add(Duration(days: 1))` so a DST shift
/// inside the span can't drift the date (the `cb6671c` bug class).
@visibleForTesting
List<DateTime> localDaysSpanned(MigraineEvent e) {
  final s = e.startedAt.toLocal();
  final start = DateTime(s.year, s.month, s.day);
  final end = e.endedAt?.toLocal();
  if (end == null) return [start];
  final endDay = DateTime(end.year, end.month, end.day);
  if (endDay.isBefore(start)) return [start];
  final out = <DateTime>[];
  for (var i = 0; ; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    if (d.isAfter(endDay)) break;
    out.add(d);
  }
  return out;
}

String _dayKey(DateTime localDay) =>
    '${DateFormat('yyyy-MM').format(localDay)}-${localDay.day}';

/// Max recorded severity per local day, keyed 'yyyy-MM-d' (matches _CalendarView's grouping key).
/// A day with multiple events keeps its most severe entry rather than whichever event was
/// iterated last (which could overwrite a real severity with null and grey out the day). A
/// multi-day event applies its severity to every day it spans.
@visibleForTesting
Map<String, int?> severityByLocalDay(Iterable<MigraineEvent> events) {
  final out = <String, int?>{};
  for (final e in events) {
    for (final day in localDaysSpanned(e)) {
      final key = _dayKey(day);
      final sev = e.severity;
      final prev = out[key];
      if (sev != null && (prev == null || sev > prev)) {
        out[key] = sev;
      } else {
        out.putIfAbsent(key, () => null);
      }
    }
  }
  return out;
}

/// Every event on each local day it spans, keyed 'yyyy-MM-d' (same key shape as
/// [severityByLocalDay]) — lets a Calendar day tap resolve back to the actual entry/entries
/// covering that day (backlog #9), including the middle of a multi-day migraine (backlog #10).
@visibleForTesting
Map<String, List<MigraineEvent>> eventsByLocalDay(
  Iterable<MigraineEvent> events,
) {
  final out = <String, List<MigraineEvent>>{};
  for (final e in events) {
    for (final day in localDaysSpanned(e)) {
      (out[_dayKey(day)] ??= []).add(e);
    }
  }
  return out;
}

/// All 'yyyy-MM' month keys from [earliest]'s month through [latest]'s month, newest first.
/// Every month in the range renders — migraine-free ones included — because skipping empty
/// months compresses the gaps and gives a false impression of how long it's been between
/// migraines (Steve, 2026-09-03).
@visibleForTesting
List<String> monthKeysBetween(DateTime earliest, DateTime latest) {
  final lo = earliest.year * 12 + earliest.month - 1;
  final hi = latest.year * 12 + latest.month - 1;
  return [
    for (var m = hi; m >= lo; m--)
      '${(m ~/ 12).toString().padLeft(4, '0')}-'
          '${(m % 12 + 1).toString().padLeft(2, '0')}',
  ];
}

/// Day keys (same 'yyyy-MM-d' shape as the other maps) whose migraine continues into the NEXT
/// local day — each such day draws a connecting bar toward its successor, tying a multi-day
/// migraine's cells together visually.
@visibleForTesting
Set<String> spanLinkKeys(Iterable<MigraineEvent> events) {
  final out = <String>{};
  for (final e in events) {
    final days = localDaysSpanned(e);
    for (var i = 0; i + 1 < days.length; i++) {
      out.add(_dayKey(days[i]));
    }
  }
  return out;
}

class _CalendarView extends StatelessWidget {
  final List<MigraineEvent> events;
  final void Function(DateTime localDay, List<MigraineEvent> dayEvents)
  onDayTap;
  final DateTime today;
  const _CalendarView({
    required this.events,
    required this.onDayTap,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    // Weekday-aligned heat grid per month. Spanned days (not just start days) decide the hit
    // cells, so a migraine crossing a month boundary colors into the later month too.
    final byMonth = <String, Set<int>>{};
    var earliest = today;
    var latest = today;
    for (final e in events) {
      for (final d in localDaysSpanned(e)) {
        (byMonth[DateFormat('yyyy-MM').format(d)] ??= {}).add(d.day);
        if (d.isBefore(earliest)) earliest = d;
        if (d.isAfter(latest)) latest = d;
      }
    }
    final severityByDay = severityByLocalDay(events);
    final eventsByDay = eventsByLocalDay(events);
    final linkDays = spanLinkKeys(events);
    // With no entries this collapses to just the current month (all grey), still tappable so a
    // first entry can be created by tapping a date rather than only via the FAB.
    final months = monthKeysBetween(earliest, latest);
    // Built lazily: 15+ years of history is ~190 month cards, so the empty in-between months
    // must not all be constructed up front.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: months.length + (events.isEmpty ? 1 : 0),
      itemBuilder: (context, i) {
        if (events.isEmpty && i == 0) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'No migraines logged yet — tap a date below to add one.',
              textAlign: TextAlign.center,
            ),
          );
        }
        final m = months[events.isEmpty ? i - 1 : i];
        return _MonthGrid(
          month: m,
          days: byMonth[m] ?? const {},
          severityByDay: severityByDay,
          eventsByDay: eventsByDay,
          linkDays: linkDays,
          onDayTap: onDayTap,
          today: today,
        );
      },
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final String month; // yyyy-MM
  final Set<int> days;
  final Map<String, int?> severityByDay;
  final Map<String, List<MigraineEvent>> eventsByDay;

  /// Days whose migraine continues into the next day — they draw a connecting bar.
  final Set<String> linkDays;
  final void Function(DateTime localDay, List<MigraineEvent> dayEvents)
  onDayTap;
  final DateTime today;
  const _MonthGrid({
    required this.month,
    required this.days,
    required this.severityByDay,
    required this.eventsByDay,
    required this.linkDays,
    required this.onDayTap,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final mo = int.parse(parts[1]);
    final daysInMonth = DateTime(year, mo + 1, 0).day;
    // Weekday alignment (backlog #10). First day of week comes from the device locale via
    // MaterialLocalizations (0 = Sunday) — no in-app setting; with the app English-only today
    // this resolves Sunday-first, and picks up Monday-first locales automatically if/when
    // localisation is added. narrowWeekdays is indexed Sunday-first, same convention.
    final loc = MaterialLocalizations.of(context);
    final firstDow = loc.firstDayOfWeekIndex;
    // Column of the month's 1st: Dart weekday is 1=Mon..7=Sun; `% 7` re-bases to Sunday-first.
    final lead = (DateTime(year, mo, 1).weekday % 7 - firstDow + 7) % 7;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++)
        const Expanded(child: SizedBox(height: 48)),
      for (var d = 1; d <= daysInMonth; d++)
        Expanded(child: _dayCell(context, year, mo, d, days.contains(d))),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox(height: 48)));
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(DateTime(year, mo)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        loc.narrowWeekdays[(firstDow + i) % 7],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < cells.length ~/ 7; row++)
              Row(children: cells.sublist(row * 7, row * 7 + 7)),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, int year, int mo, int day, bool hit) {
    // Match the List view's severity badge scale (green→red buckets), not a saturation ramp.
    final sev = severityByDay['$month-$day'];
    final color = hit
        ? severityColor(sev)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final isToday = year == today.year && mo == today.month && day == today.day;
    // Multi-day migraines are tied together by a bar behind the dots: this cell draws its right
    // half when its migraine continues into the next day, and its left half when the previous
    // day's continues into it. Each half runs to the cell edge, so two adjacent cells meet and
    // read as one continuous line in the severity color; at a row/month edge the lone half still
    // signals "continues beyond here". `DateTime(year, mo, day - 1)` normalises day 0 into the
    // previous month, which is what links a boundary-crossing span across two month cards.
    final linkRight = linkDays.contains('$month-$day');
    final linkLeft = linkDays.contains(_dayKey(DateTime(year, mo, day - 1)));
    // The visual dot stays small (30x30), but the *tappable* area is the whole grid cell: height
    // is pinned to the 48px Android minimum touch-target size and width is 1/7 of the card (≥44px
    // on a typical 360dp phone) — the original fixed 48x48 cells came from an
    // accessibility-guideline test; a 7-column grid trades a few px of width on narrow screens.
    return SizedBox(
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onDayTap(
          DateTime(year, mo, day),
          eventsByDay['$month-$day'] ?? const [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (linkLeft || linkRight)
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: linkLeft
                          ? Container(
                              key: ValueKey('link-left-$month-$day'),
                              height: 6,
                              color: color,
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: linkRight
                          ? Container(
                              key: ValueKey('link-right-$month-$day'),
                              height: 6,
                              color: color,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                // Anchor "today" on the grid regardless of whether it has an entry — most useful in
                // the empty-calendar state, where every cell is otherwise identical grey.
                border: isToday
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.bold : null,
                  color: hit ? onStatusColor(color) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
