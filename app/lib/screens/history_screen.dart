import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../repositories/megrim_repository.dart';
import 'event_detail_screen.dart';

/// History (SPEC §4.3): list + month-grid calendar toggle; swipe-to-delete with Snackbar undo.
class HistoryScreen extends StatefulWidget {
  final MegrimRepository repo;
  const HistoryScreen({super.key, required this.repo});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _calendar = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: _calendar ? 'List view' : 'Calendar view',
            icon: Icon(_calendar ? Icons.list : Icons.calendar_month),
            onPressed: () => setState(() => _calendar = !_calendar),
          ),
        ],
      ),
      body: StreamBuilder<List<MigraineEvent>>(
        stream: widget.repo.watchEvents(),
        builder: (context, snap) {
          final events = snap.data ?? const [];
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (events.isEmpty) {
            return const Center(child: Text('No migraines logged yet.'));
          }
          return _calendar ? _CalendarView(events: events) : _listView(events);
        },
      ),
    );
  }

  Widget _listView(List<MigraineEvent> events) {
    final df = DateFormat('EEE d MMM yyyy, HH:mm');
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = events[i];
        return Dismissible(
          key: ValueKey(e.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _delete(e.id),
          child: ListTile(
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

class _CalendarView extends StatelessWidget {
  final List<MigraineEvent> events;
  const _CalendarView({required this.events});

  @override
  Widget build(BuildContext context) {
    // Group by month; render a simple heat grid per month with events.
    final byMonth = <String, Set<int>>{};
    final severityByDay = <String, int>{};
    for (final e in events) {
      final l = e.startedAt.toLocal();
      final key = DateFormat('yyyy-MM').format(l);
      (byMonth[key] ??= {}).add(l.day);
      severityByDay['$key-${l.day}'] = e.severity ?? 0;
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final m in months)
          _MonthGrid(
            month: m,
            days: byMonth[m]!,
            severityByDay: severityByDay,
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final String month; // yyyy-MM
  final Set<int> days;
  final Map<String, int> severityByDay;
  const _MonthGrid(
      {required this.month, required this.days, required this.severityByDay});

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
                  _dayCell(context, d, days.contains(d)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(BuildContext context, int day, bool hit) {
    final sev = severityByDay['$month-$day'] ?? 0;
    final color = hit
        ? Color.lerp(Colors.orange.shade200, Colors.red.shade700, sev / 10)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$day', style: const TextStyle(fontSize: 11)),
    );
  }
}
