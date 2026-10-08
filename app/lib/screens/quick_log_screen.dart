import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../analytics/dashboard.dart';
import '../database/database.dart';
import '../legal.dart';
import '../models/backup_status.dart';
import '../repositories/megrim_repository.dart';
import '../widgets/severity_badge.dart' show StatusColors;
import '../widgets/days_since_card.dart';
import 'event_detail_screen.dart';

/// Quick Log (SPEC §4.2): one tap to start a migraine; an active view with an elapsed timer,
/// severity slider and notes; one tap to end. GPS is deferred, so entries use the home location
/// for enrichment automatically.
class QuickLogScreen extends StatefulWidget {
  /// Bumped by [HomeShell] whenever this tab is opened, so the backup line re-reads after an
  /// export done on the Settings tab (IndexedStack keeps this screen alive, so it would otherwise
  /// keep showing the date from when it was first built).
  final int refreshToken;

  /// Bumped by [HomeShell] when the app-icon "Log migraine" shortcut is used (backlog #23): start
  /// a migraine, unless one is already in progress.
  final int startToken;

  /// Switches the shell to the Settings tab — tapping the backup line goes there.
  final VoidCallback? onOpenSettings;
  final MegrimRepository repo;
  const QuickLogScreen({
    super.key,
    required this.repo,
    this.refreshToken = 0,
    this.startToken = 0,
    this.onOpenSettings,
  });

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  MigraineEvent? _active;

  /// Completes once the in-progress check has run, so a shortcut can't start a second migraine
  /// before we know whether one is already going.
  late Future<void> _activeLoaded;
  Timer? _ticker;
  final _notes = TextEditingController();

  /// Backup reminder (backlog #14); only rendered once the user has opted in to an interval.
  BackupStatus _backup = const BackupStatus(
      lastBackupAt: null, reminderDays: kBackupReminderOff, daysSince: null);

  @override
  void initState() {
    super.initState();
    _activeLoaded = _loadActive();
    _loadBackup();
    if (widget.startToken > 0) _startFromShortcut();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_active != null && mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(QuickLogScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _loadBackup();
    if (old.startToken != widget.startToken) _startFromShortcut();
  }

  Future<void> _loadBackup() async {
    final s = await widget.repo.backupStatus();
    if (mounted) setState(() => _backup = s);
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
    if (!mounted) return;
    setState(() {
      _active = ongoing.isNotEmpty ? ongoing.first : null;
      _notes.text = _active?.notes ?? '';
    });
  }

  /// The app-icon shortcut: start a migraine, or just show the one already in progress.
  Future<void> _startFromShortcut() async {
    await _activeLoaded;
    if (!mounted || _active != null) return;
    final started = _start();
    _activeLoaded = started;
    await started;
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
            child: Text('Discard',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            // Expanded + ellipsis so a narrow screen (found on a Nexus S/API 26 emulator: a 12px
            // horizontal RenderFlex overflow) truncates the title instead of overflowing the row.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Megrim',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  Text(kAppSubtitle,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
      // The backup line sits outside the scrollable view so it stays at the bottom of the screen
      // rather than below the content — deliberately the least prominent thing here.
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _active == null ? _idleView() : _activeView(),
            ),
          ),
          _backupLine(),
        ],
      ),
    );
  }

  /// "Last backup: 12 days ago" with a green or orange dot, shown only when the user has turned
  /// the reminder on in Settings (backlog #14). Tapping opens Settings, where it can be changed.
  Widget _backupLine() {
    if (!_backup.reminderEnabled) return const SizedBox.shrink();
    final color =
        _backup.isOverdue ? StatusColors.serious : StatusColors.good;
    return InkWell(
      onTap: widget.onOpenSettings,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'Last backup: ${_backup.ageLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // Both the idle and active views are scrollable rather than a plain Column + Spacer — on a
  // small screen or in landscape (found on a Nexus S / API 26 emulator), the fixed content plus
  // the on-screen keyboard could overflow the viewport and clip instead of scrolling, at one point
  // making the "MIGRAINE ENDED" button unreachable.
  Widget _idleView() => SingleChildScrollView(
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
            const SizedBox(height: 48),
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
            const SizedBox(height: 24),
          ],
        ),
      );

  Widget _activeView() {
    final elapsed = DateTime.now().toUtc().difference(_active!.startedAt.toUtc());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
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
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
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
