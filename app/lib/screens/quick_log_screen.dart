import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../analytics/dashboard.dart';
import '../database/database.dart';
import '../legal.dart';
import '../repositories/megrim_repository.dart';
import '../widgets/days_since_card.dart';
import 'event_detail_screen.dart';

/// Quick Log (SPEC §4.2): one tap to start a migraine; an active view with an elapsed timer,
/// severity slider and notes; one tap to end. GPS is deferred, so entries use the home location
/// for enrichment automatically.
class QuickLogScreen extends StatefulWidget {
  final MegrimRepository repo;
  const QuickLogScreen({super.key, required this.repo});

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  MigraineEvent? _active;
  Timer? _ticker;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadActive();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_active != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadActive() async {
    final events = await widget.repo.db.select(widget.repo.db.migraineEvents).get();
    final ongoing = events.where((e) => e.endedAt == null).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    setState(() {
      _active = ongoing.isNotEmpty ? ongoing.first : null;
      _notes.text = _active?.notes ?? '';
    });
  }

  Future<void> _start() async {
    final home = await widget.repo.homeLocation;
    await widget.repo.startEvent(
      severity: 5,
      lat: home?.lat,
      lon: home?.lon,
      label: home?.label,
    );
    await _loadActive();
  }

  Future<void> _end() async {
    if (_active == null) return;
    await widget.repo.updateEvent(MigraineEventsCompanion(
      id: Value(_active!.id),
      notes: Value(_notes.text.isEmpty ? null : _notes.text),
    ));
    await widget.repo.endEvent(_active!.id);
    // Re-check weather at end (cheap; same day) — SPEC §5.
    await widget.repo.enrichment.enqueue(_active!.id);
    widget.repo.processEnrichmentQueue().catchError((_) {});
    await _loadActive();
  }

  /// Stop and delete an in-progress migraine — e.g. started by accident (review item #1).
  Future<void> _discard() async {
    if (_active == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this migraine?'),
        content: const Text(
            'This stops the timer and permanently deletes the in-progress entry.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await widget.repo.deleteEvent(_active!.id);
    await _loadActive();
    if (removed != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Migraine discarded'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await widget.repo.restoreEvent(removed.event, removed.derived);
            await _loadActive();
          },
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/logo.png', width: 40, height: 40),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Megrim',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text(kAppSubtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: Center(
        child: _active == null ? _idleView() : _activeView(),
      ),
    );
  }

  Widget _idleView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Days-since-last graphic so the idle Log page isn't blank (review item #8).
            FutureBuilder<DashboardResult>(
              future: widget.repo.dashboard(),
              builder: (context, snap) {
                final dash = snap.data;
                if (dash == null || dash.isEmpty) return const SizedBox.shrink();
                return DaysSinceCard(summary: dash.summary);
              },
            ),
            const Spacer(),
            const Icon(Icons.self_improvement, size: 72),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.add),
                label: const Text('LOG MIGRAINE', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tap to start. You can add details any time.',
                style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
          ],
        ),
      );

  Widget _activeView() {
    final elapsed = DateTime.now().toUtc().difference(_active!.startedAt.toUtc());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Migraine in progress',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(_fmtDuration(elapsed),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 24),
          Text('Severity: ${_active!.severity ?? 5} / 10'),
          Slider(
            value: (_active!.severity ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_active!.severity ?? 5}',
            onChanged: (v) async {
              await widget.repo.updateEvent(MigraineEventsCompanion(
                id: Value(_active!.id),
                severity: Value(v.round()),
              ));
              await _loadActive();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: _end,
              icon: const Icon(Icons.stop),
              label: const Text('MIGRAINE ENDED'),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    EventDetailScreen(repo: widget.repo, eventId: _active!.id),
              ));
              await _loadActive();
            },
            child: const Text('Add more details'),
          ),
          TextButton.icon(
            onPressed: _discard,
            icon: const Icon(Icons.delete_outline, size: 18),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            label: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
