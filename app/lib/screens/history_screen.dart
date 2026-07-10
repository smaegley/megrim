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
  const HistoryScreen({super.key, required this.repo});

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
                if (events.isEmpty) {
                  return const Center(child: Text('No migraines logged yet.'));
                }
                return _view == _HistoryView.calendar
                    ? _CalendarView(events: events, onDayTap: _onCalendarDayTap)
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
        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.delete,
                color: Theme.of(context).colorScheme.onError),
          ),
          onDismissed: (_) => _delete(e.id),
          child: ListTile(
            leading: SeverityBadge(severity: e.severity),
            title: Text(df.format(e.startedAt.toLocal())),
            subtitle: Text([
              if (e.severity != null) 'Severity ${e.severity}/10',
              if (e.endedAt == null) 'ongoing',
            ].join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EventDetailScreen(repo: widget.repo, eventId: e.id),
            )),
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventDetailScreen(repo: widget.repo, eventId: id),
    ));
  }

  /// Calendar day tap (backlog #9): exactly one entry that day opens it directly; several offer a
  /// picker to choose which one; none starts a new past entry pre-dated to the tapped day (instead
  /// of "now" — the whole point of tapping a specific day rather than using the FAB).
  Future<void> _onCalendarDayTap(
      DateTime localDay, List<MigraineEvent> dayEvents) async {
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
                subtitle: Text([
                  if (e.severity != null) 'Severity ${e.severity}/10',
                  if (e.endedAt == null) 'ongoing',
                ].join(' · ')),
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
    final at =
        DateTime(localDay.year, localDay.month, localDay.day, 12).toUtc();
    await widget.repo.updateEvent(MigraineEventsCompanion(
      id: Value(id),
      startedAt: Value(at),
      endedAt: Value(at),
    ));
    await _openEvent(id);
  }

  Future<void> _openEvent(String id) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EventDetailScreen(repo: widget.repo, eventId: id),
    ));
  }

  Future<void> _delete(String id) async {
    final removed = await widget.repo.deleteEvent(id);
    if (removed == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Entry deleted'),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () =>
            widget.repo.restoreEvent(removed.event, removed.derived),
      ),
    ));
  }
}

/// Max recorded severity per local day, keyed 'yyyy-MM-d' (matches _CalendarView's grouping key).
/// A day with multiple events keeps its most severe entry rather than whichever event was
/// iterated last (which could overwrite a real severity with null and grey out the day).
@visibleForTesting
Map<String, int?> severityByLocalDay(Iterable<MigraineEvent> events) {
  final out = <String, int?>{};
  for (final e in events) {
    final l = e.startedAt.toLocal();
    final key = '${DateFormat('yyyy-MM').format(l)}-${l.day}';
    final sev = e.severity;
    final prev = out[key];
    if (sev != null && (prev == null || sev > prev)) {
      out[key] = sev;
    } else {
      out.putIfAbsent(key, () => null);
    }
  }
  return out;
}

/// Every event on each local day, keyed 'yyyy-MM-d' (same key shape as [severityByLocalDay]) —
/// lets a Calendar day tap resolve back to the actual entry/entries on that day (backlog #9).
@visibleForTesting
Map<String, List<MigraineEvent>> eventsByLocalDay(Iterable<MigraineEvent> events) {
  final out = <String, List<MigraineEvent>>{};
  for (final e in events) {
    final l = e.startedAt.toLocal();
    final key = '${DateFormat('yyyy-MM').format(l)}-${l.day}';
    (out[key] ??= []).add(e);
  }
  return out;
}

class _CalendarView extends StatelessWidget {
  final List<MigraineEvent> events;
  final void Function(DateTime localDay, List<MigraineEvent> dayEvents) onDayTap;
  const _CalendarView({required this.events, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    // Group by month; render a simple heat grid per month with events.
    final byMonth = <String, Set<int>>{};
    for (final e in events) {
      final l = e.startedAt.toLocal();
      final key = DateFormat('yyyy-MM').format(l);
      (byMonth[key] ??= {}).add(l.day);
    }
    final severityByDay = severityByLocalDay(events);
    final eventsByDay = eventsByLocalDay(events);
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        for (final m in months)
          _MonthGrid(
            month: m,
            days: byMonth[m]!,
            severityByDay: severityByDay,
            eventsByDay: eventsByDay,
            onDayTap: onDayTap,
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final String month; // yyyy-MM
  final Set<int> days;
  final Map<String, int?> severityByDay;
  final Map<String, List<MigraineEvent>> eventsByDay;
  final void Function(DateTime localDay, List<MigraineEvent> dayEvents) onDayTap;
  const _MonthGrid({
    required this.month,
    required this.days,
    required this.severityByDay,
    required this.eventsByDay,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final mo = int.parse(parts[1]);
    final daysInMonth = DateTime(year, mo + 1, 0).day;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMMM yyyy').format(DateTime(year, mo)),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= daysInMonth; d++)
                  _dayCell(context, year, mo, d, days.contains(d)),
              ],
            ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onDayTap(
          DateTime(year, mo, day), eventsByDay['$month-$day'] ?? const []),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 11,
            color: hit ? onStatusColor(color) : null,
          ),
        ),
      ),
    );
  }
}
