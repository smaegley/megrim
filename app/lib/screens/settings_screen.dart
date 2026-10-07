import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/database.dart';
import '../legal.dart';
import '../models/app_lock_timeout.dart';
import '../models/backup_status.dart';
import '../models/home_location.dart';
import '../repositories/megrim_repository.dart';
import '../services/app_lock.dart';
import '../services/import_service.dart';
import '../services/report_pdf.dart';
import '../widgets/location_picker.dart';
import '../widgets/severity_badge.dart' show StatusColors;
import 'manage_vocab_screen.dart';

enum _ExportAction { share, save }

/// Settings (SPEC §4.6): home location, vocab management, export/import, donate, About.
class SettingsScreen extends StatefulWidget {
  final MegrimRepository repo;
  const SettingsScreen({super.key, required this.repo});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  MegrimRepository get repo => widget.repo;

  /// The displayed home location, held directly in state (not via a FutureBuilder). After a change
  /// we set it straight from the picked value, so the label updates immediately — the old
  /// FutureBuilder re-read the DB, and that read got queued behind reEnrichAll's heavy DB work, so
  /// the new label didn't surface until the screen was left and reopened (backlog #7).
  HomeLocation? _home;
  bool _homeLoaded = false;

  /// Displayed directly from state like [_home] (same backlog-#7 lesson: don't re-read the DB
  /// through a FutureBuilder right after writing it).
  bool _weatherEnrichment = false;

  /// Backup reminder (backlog #14). Held in state for the same reason as the two above.
  BackupStatus _backup = const BackupStatus(
      lastBackupAt: null, reminderDays: kBackupReminderOff, daysSince: null);

  @override
  void initState() {
    super.initState();
    _loadHome();
    _loadWeatherEnrichment();
    _loadBackup();
  }

  Future<void> _loadBackup() async {
    final s = await repo.backupStatus();
    if (mounted) setState(() => _backup = s);
  }

  /// Called by the export paths after a JSON export actually completed (saved, or shared and the
  /// sheet reported success). CSV doesn't count: it can't be imported back, so it isn't a backup.
  Future<void> _recordBackup() async {
    await repo.markBackedUp();
    await _loadBackup();
  }

  Future<void> _pickReminderInterval() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Remind me to back up'),
        children: [
          // SimpleDialogOption + ListTile, matching the Export dialog below rather than
          // RadioListTile, whose groupValue/onChanged are deprecated in this Flutter.
          for (final days in kBackupReminderChoices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, days),
              child: ListTile(
                leading: Icon(days == _backup.reminderDays
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(backupReminderLabel(days)),
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await repo.setBackupReminderDays(chosen);
    await _loadBackup();
  }

  Future<void> _loadWeatherEnrichment() async {
    final on = await repo.weatherEnrichmentEnabled;
    if (mounted) setState(() => _weatherEnrichment = on);
  }

  Future<void> _setWeatherEnrichment(bool on) async {
    setState(() => _weatherEnrichment = on);
    await repo.setWeatherEnrichmentEnabled(on);
    if (!mounted) return;
    if (on) {
      // Backfill weather for everything already logged; runs in the background like the
      // home-location change path.
      unawaited(repo.reEnrichAll());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Weather enrichment on — fetching weather for your entries…')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Weather enrichment off — no more automatic network requests.')));
    }
  }

  Future<void> _loadHome() async {
    final h = await repo.homeLocation;
    if (mounted) {
      setState(() {
        _home = h;
        _homeLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home location'),
            subtitle: Text(_home?.label ?? (_homeLoaded ? '—' : '…')),
            onTap: () => _changeHome(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: const Text('Weather enrichment'),
            subtitle: Text(_weatherEnrichment
                ? 'Fetches weather for entries from Open-Meteo (rounded location + date only)'
                : 'Off — no automatic network use (only searches you type)'),
            value: _weatherEnrichment,
            onChanged: _setWeatherEnrichment,
          ),
          const Divider(),
          _vocabTile(context, 'Triggers', VocabKind.trigger),
          _vocabTile(context, 'Head locations', VocabKind.headLocation),
          _vocabTile(context, 'Medications', VocabKind.medication),
          const Divider(),
          ListTile(
            leading: Icon(
              _backup.isOverdue ? Icons.backup_outlined : Icons.backup,
              color: _backup.isOverdue ? StatusColors.serious : null,
            ),
            title: const Text('Last backup'),
            subtitle: Text(
              '${_backup.ageLabel} · ${backupReminderLabel(_backup.reminderDays)}'
              '${_backup.isOverdue ? ' · due' : ''}',
              style: _backup.isOverdue
                  ? const TextStyle(color: StatusColors.serious)
                  : null,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _pickReminderInterval,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export (JSON backup)'),
            onTap: () => _exportJson(context),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export (CSV)'),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export report (PDF)'),
            subtitle: const Text('A printable summary to share with a clinician'),
            onTap: () => _exportReport(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import (JSON)'),
            onTap: () => _import(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Import format guide'),
            subtitle: const Text('Bring in data from another app'),
            onTap: () => _launch(context, kImportDocUrl),
          ),
          if (AppLockScope.maybeOf(context) case final lock?) ...[
            const Divider(),
            ..._privacyTiles(context, lock),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Donate'),
            subtitle: const Text('Support development'),
            onTap: () => _launch(context, 'https://ko-fi.com/smaegley'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source code'),
            onTap: () => _launch(context, kSourceUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About & privacy'),
            onTap: () => _about(context),
          ),
        ],
      ),
    );
  }

  /// Privacy (backlog #24): app lock with the phone's own unlock, and hide from recent apps.
  List<Widget> _privacyTiles(BuildContext context, AppLockController lock) => [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: const Text('App lock'),
          subtitle: const Text('Ask for your fingerprint, face or phone PIN when opening Megrim'),
          value: lock.enabled,
          onChanged: (on) => _setAppLock(context, lock, on),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Lock after'),
          subtitle: Text('${appLockTimeoutLabel(lock.timeout)} in the background'),
          enabled: lock.enabled,
          onTap: () => _pickLockTimeout(lock),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off_outlined),
          title: const Text('Hide in recent apps'),
          subtitle: Text(Platform.isAndroid
              ? 'Blank Megrim in the app switcher. Also blocks screenshots of the app.'
              : 'Blank Megrim in the app switcher.'),
          value: lock.hideInSwitcher,
          onChanged: lock.setHideInSwitcher,
        ),
      ];

  Future<void> _setAppLock(BuildContext context, AppLockController lock, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await lock.setEnabled(on);
    if (!context.mounted) return;
    switch (outcome) {
      case AuthOutcome.success:
        messenger.showSnackBar(SnackBar(
            content: Text(on ? 'App lock on.' : 'App lock off.'), duration: const Duration(seconds: 2)));
      case AuthOutcome.noCredential:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No screen lock on this phone'),
            content: const Text('App lock uses your phone\'s own unlock — fingerprint, face, or '
                'PIN, pattern or password. Set a screen lock in your phone\'s settings first, then '
                'turn app lock on here.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      case AuthOutcome.lockedOut:
        messenger.showSnackBar(const SnackBar(
            content: Text('Too many attempts. Wait a moment, then try again.')));
      case AuthOutcome.cancelled:
        break;
      case AuthOutcome.error:
        messenger.showSnackBar(
            const SnackBar(content: Text('Couldn\'t ask for your phone\'s unlock.')));
    }
  }

  Future<void> _pickLockTimeout(AppLockController lock) async {
    final chosen = await showDialog<Duration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Lock after'),
        children: [
          for (final d in kAppLockTimeoutChoices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: ListTile(
                leading: Icon(
                    d == lock.timeout ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(appLockTimeoutLabel(d)),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await lock.setTimeout(chosen);
  }

  Widget _vocabTile(BuildContext context, String title, String kind) => ListTile(
        leading: const Icon(Icons.label_outline),
        title: Text('Manage $title'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ManageVocabScreen(repo: repo, kind: kind, title: title),
        )),
      );

  Future<void> _changeHome(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    HomeLocation? picked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change home location'),
        content: SizedBox(
          width: 400,
          child: LocationPickerField(onSelected: (loc) => picked = loc),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save & re-enrich')),
        ],
      ),
    );
    if (confirmed == true && picked != null) {
      await repo.setHomeLocation(picked!);
      // Update the tile straight from the picked value — no DB re-read, so it shows immediately
      // even before the (slow) re-enrich below runs (backlog #7).
      if (mounted) setState(() => _home = picked);
      messenger.showSnackBar(
          const SnackBar(content: Text('Re-enriching entries…')));
      await repo.reEnrichAll();
      messenger.showSnackBar(const SnackBar(content: Text('Done.')));
    }
  }

  Future<void> _exportJson(BuildContext context) async {
    final json = await repo.exportJson();
    if (!context.mounted) return;
    final name = ExportServiceFilename.json();
    // Only a JSON export counts as a backup — it is the only format the app can import back.
    if (await _exportContent(context, json, name)) await _recordBackup();
  }

  /// The printable report (backlog #12). Deliberately does NOT count as a backup for the reminder:
  /// a PDF can't be imported back, the same reason CSV doesn't.
  Future<void> _exportReport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Building report…'), duration: Duration(seconds: 2)));
    try {
      final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      // Exact glyph coverage of the embedded font, so anything it can't draw becomes "?" rather
      // than silently disappearing.
      final coverage = TtfParser(regular).charToGlyphIndexMap;
      final content = await repo.reportContent(canRender: coverage.containsKey);
      final bytes = await renderReportPdf(content, regular: regular, bold: bold);
      if (!context.mounted) return;
      await _exportBytes(context, bytes, ExportServiceFilename.pdf());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Report failed: $e')));
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final csv = await repo.exporter.toCsv();
    if (!context.mounted) return;
    final name = ExportServiceFilename.csv();
    await _exportContent(context, csv, name);
  }

  /// Offer both delivery paths (SPEC §7.1): the share sheet, and a direct "Save to device" via
  /// Android's Storage Access Framework (file_picker's saveFile). The share sheet's available
  /// targets depend entirely on what's installed — some phones/emulators have nothing registered
  /// to save straight to local storage, so "share only" isn't a reliable substitute for this.
  /// Returns true when the export actually reached somewhere: saved to a file the user chose, or
  /// handed to a share target that reported success. Cancelling either returns false.
  Future<bool> _exportContent(
      BuildContext context, String content, String filename) =>
      _exportBytes(context, Uint8List.fromList(utf8.encode(content)), filename);

  /// Returns true when the export actually reached somewhere: saved to a file the user chose, or
  /// handed to a share target that reported success. Cancelling either returns false.
  Future<bool> _exportBytes(
      BuildContext context, Uint8List bytes, String filename) async {
    final action = await showDialog<_ExportAction>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _ExportAction.share),
            child: const ListTile(
              leading: Icon(Icons.share_outlined),
              title: Text('Share'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _ExportAction.save),
            child: const ListTile(
              leading: Icon(Icons.save_alt_outlined),
              title: Text('Save to device'),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return false;
    if (action == _ExportAction.share) {
      return _shareBytes(bytes, filename);
    }
    return _saveToFile(context, bytes, filename);
  }

  Future<bool> _saveToFile(
      BuildContext context, Uint8List bytes, String filename) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // The system save dialog is Megrim's own trip out, so it doesn't count as leaving (#24).
      final path = await AppLockScope.external(
          context, () => FilePicker.platform.saveFile(fileName: filename, bytes: bytes));
      if (path != null) {
        messenger.showSnackBar(const SnackBar(content: Text('Saved.')));
        return true;
      }
      // path == null: the user cancelled the save dialog — nothing to report.
      return false;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
      return false;
    }
  }

  Future<bool> _shareBytes(Uint8List bytes, String filename) async {
    // iPadOS presents the share sheet as a popover, which needs an explicit source rect —
    // without one share_plus throws there. Anchoring to this screen's bounds is enough;
    // Android and iPhone ignore it. Computed before the first await, while context is fresh.
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes);
    if (!mounted) return false;
    final result = await AppLockScope.external(
        context,
        () => Share.shareXFiles([XFile(file.path)],
            subject: filename, sharePositionOrigin: origin));
    // shareXFiles() resolves once the user picks a target, not once that app has finished reading
    // the file over its content:// URI — so delete after a delay (best-effort) rather than
    // immediately, to avoid a race with a slow receiving app. Worst case it lingers in the
    // OS-managed cache dir, which Android reclaims under storage pressure anyway.
    unawaited(Future.delayed(const Duration(seconds: 30), () async {
      try {
        await file.delete();
      } catch (_) {}
    }));
    // Only a completed share counts. `dismissed` means the user backed out of the sheet, and
    // `unavailable` means the platform couldn't say — neither is evidence the file landed anywhere.
    return result.status == ShareResultStatus.success;
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await AppLockScope.external(context, () => FilePicker.platform.pickFiles(withData: true));
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (!context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import'),
        content: const Text(
            'Merge with your existing entries, or replace everything?\n\n'
            'Replace permanently deletes all current entries first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Merge')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Replace',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (replace == null) return;

    try {
      final r = await repo.importer.importJsonBytes(bytes, replace: replace);
      messenger.showSnackBar(SnackBar(
          content: Text('Imported ${r.imported}, skipped ${r.skipped}.')));
      await repo.processEnrichmentQueue();
    } on ImportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _launch(BuildContext context, String url) async {
    // Launch directly rather than gating on canLaunchUrl(): a web ACTION_VIEW is exempt from
    // Android 11+ package-visibility, whereas canLaunchUrl() needs the <queries> browser intent
    // declared in AndroidManifest and returns false without it — the old cause of a silent no-op.
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('no handler for $url');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  Future<void> _about(BuildContext context) async {
    final theme = Theme.of(context);
    showAboutDialog(
      context: context,
      applicationName: 'Megrim',
      applicationVersion: kAppVersion,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/logo.png', width: 56, height: 56),
      ),
      applicationLegalese: 'GPL-3.0-or-later · $kWeatherAttribution',
      children: [
        const SizedBox(height: 12),
        Text(kAppTitle, style: theme.textTheme.titleMedium),
        Text(kAppSubtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        Text(kShortDescription,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(kFullDescription),
        const Divider(height: 24),
        const Text(kPrivacySummary),
        const SizedBox(height: 12),
        const Text(kMedicalDisclaimer),
      ],
    );
  }
}

/// Small helper to keep filename generation with today's date in one place.
class ExportServiceFilename {
  static String json() => _name('json');
  static String csv() => _name('csv');

  /// The report is named "report", not "export": it is a document to hand over, not a backup, and
  /// the app cannot read it back.
  static String pdf() => 'megrim-report-${_stamp()}.pdf';

  static String _name(String ext) => 'megrim-export-${_stamp()}.$ext';

  static String _stamp() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
