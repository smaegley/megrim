import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/database.dart';
import '../l10n/l10n.dart';
import '../legal.dart';
import '../models/app_lock_timeout.dart';
import '../models/backup_status.dart';
import '../models/home_location.dart';
import '../repositories/megrim_repository.dart';
import '../services/app_lock.dart';
import '../services/import_service.dart';
import '../services/notifications.dart';
import '../services/report_pdf.dart';
import '../widgets/location_picker.dart';
import '../widgets/severity_badge.dart' show StatusColors;
import 'manage_vocab_screen.dart';
import 'medications_screen.dart';

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
        title: Text(context.l10n.settingsBackupReminderTitle),
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
                title: Text(_reminderLabel(context.l10n, days)),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.settingsWeatherOnSnack)));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.settingsWeatherOffSnack)));
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(l.settingsHomeLocation),
            subtitle: Text(_home?.label ?? (_homeLoaded ? '—' : '…')),
            onTap: () => _changeHome(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: Text(l.settingsWeather),
            subtitle: Text(_weatherEnrichment
                ? l.settingsWeatherOnSubtitle
                : l.settingsWeatherOffSubtitle),
            value: _weatherEnrichment,
            onChanged: _setWeatherEnrichment,
          ),
          const Divider(),
          _vocabTile(context, l.settingsManageTriggers, l.settingsTriggersTitle, VocabKind.trigger),
          _vocabTile(context, l.settingsManageHeadLocations, l.settingsHeadLocationsTitle,
              VocabKind.headLocation),
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: Text(l.settingsManageMedications),
            subtitle: Text(l.settingsManageMedicationsSubtitle),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MedicationsScreen(repo: repo),
            )),
          ),
          if (NotificationsScope.maybeOf(context) case final n?) ...[
            const Divider(),
            ..._notificationTiles(context, n),
          ],
          const Divider(),
          ListTile(
            leading: Icon(
              _backup.isOverdue ? Icons.backup_outlined : Icons.backup,
              color: _backup.isOverdue ? StatusColors.serious : null,
            ),
            title: Text(l.settingsLastBackup),
            subtitle: Text(
              (_backup.isOverdue ? l.settingsBackupSubtitleDue : l.settingsBackupSubtitle)(
                  _backupAge(l, _backup.daysSince), _reminderLabel(l, _backup.reminderDays)),
              style: _backup.isOverdue
                  ? const TextStyle(color: StatusColors.serious)
                  : null,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _pickReminderInterval,
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l.settingsExportJson),
            onTap: () => _exportJson(context),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l.settingsExportCsv),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: Text(l.settingsExportReport),
            subtitle: Text(l.settingsExportReportSubtitle),
            onTap: () => _exportReport(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l.settingsImport),
            onTap: () => _import(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l.settingsImportGuide),
            subtitle: Text(l.settingsImportGuideSubtitle),
            onTap: () => _launch(context, kImportDocUrl),
          ),
          if (AppLockScope.maybeOf(context) case final lock?) ...[
            const Divider(),
            ..._privacyTiles(context, lock),
          ],
          const Divider(),
          // Not on iOS: an external tip link is allowed only on the US App Store (guideline
          // 3.1.1), and one binary serves every storefront (docs/APP_STORE.md, Option B).
          if (defaultTargetPlatform != TargetPlatform.iOS)
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: Text(l.settingsDonate),
              subtitle: Text(l.settingsDonateSubtitle),
              onTap: () => _launch(context, 'https://ko-fi.com/smaegley'),
            ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l.settingsSourceCode),
            onTap: () => _launch(context, kSourceUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.settingsAbout),
            onTap: () => _about(context),
          ),
        ],
      ),
    );
  }

  /// The daily reminder (backlog #27) and the ongoing notification (backlog #23 step 3, Android).
  List<Widget> _notificationTiles(BuildContext context, NotificationsController n) => [
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(context.l10n.settingsDailyReminder),
          subtitle: Text(n.reminder == null
              ? context.l10n.settingsOff
              : context.l10n.settingsDailyReminderOn(n.reminder!.format(context))),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _pickReminder(context, n),
        ),
        if (n.supportsOngoing)
          SwitchListTile(
            secondary: const Icon(Icons.timer_outlined),
            title: Text(context.l10n.settingsOngoingTitle),
            subtitle: Text(context.l10n.settingsOngoingSubtitle),
            value: n.ongoingEnabled,
            onChanged: (on) async {
              if (!await n.setOngoing(on) && context.mounted) _notificationsRefused(context);
            },
          ),
      ];

  Future<void> _pickReminder(BuildContext context, NotificationsController n) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.settingsDailyReminder),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              context.l10n.settingsDailyReminderExplain,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'off'),
            child: ListTile(
              leading: Icon(
                  n.reminder == null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(context.l10n.settingsOff),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'time'),
            child: ListTile(
              leading: Icon(
                  n.reminder != null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(n.reminder == null
                  ? context.l10n.settingsReminderChooseTime
                  : context.l10n.settingsReminderAtTime(n.reminder!.format(context))),
            ),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'off') {
      await n.setReminder(null);
      return;
    }
    final t = await showTimePicker(
      context: context,
      initialTime: n.reminder ?? const TimeOfDay(hour: 20, minute: 0),
      helpText: context.l10n.settingsRemindMeAt,
    );
    if (t == null || !context.mounted) return;
    if (!await n.setReminder(t) && context.mounted) _notificationsRefused(context);
  }

  void _notificationsRefused(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.settingsNotificationsRefused)));
  }

  /// Privacy (backlog #24): app lock with the phone's own unlock, and hide from recent apps.
  List<Widget> _privacyTiles(BuildContext context, AppLockController lock) => [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: Text(context.l10n.settingsAppLock),
          subtitle: Text(context.l10n.settingsAppLockSubtitle),
          value: lock.enabled,
          onChanged: (on) => _setAppLock(context, lock, on),
        ),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(context.l10n.settingsLockAfter),
          subtitle: Text(
              context.l10n.settingsLockAfterSubtitle(_lockTimeoutLabel(context.l10n, lock.timeout))),
          enabled: lock.enabled,
          onTap: () => _pickLockTimeout(lock),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.visibility_off_outlined),
          title: Text(context.l10n.settingsHideInRecents),
          subtitle: Text(Platform.isAndroid
              ? context.l10n.settingsHideInRecentsAndroid
              : context.l10n.settingsHideInRecentsIos),
          value: lock.hideInSwitcher,
          onChanged: lock.setHideInSwitcher,
        ),
      ];

  Future<void> _setAppLock(BuildContext context, AppLockController lock, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final outcome = await lock.setEnabled(on);
    if (!context.mounted) return;
    switch (outcome) {
      case AuthOutcome.success:
        messenger.showSnackBar(SnackBar(
            content: Text(on ? l.settingsAppLockOn : l.settingsAppLockOff),
            duration: const Duration(seconds: 2)));
      case AuthOutcome.noCredential:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.settingsNoScreenLockTitle),
            content: Text(l.settingsNoScreenLockBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel)),
            ],
          ),
        );
      case AuthOutcome.lockedOut:
        messenger.showSnackBar(SnackBar(content: Text(l.settingsTooManyAttempts)));
      case AuthOutcome.cancelled:
        break;
      case AuthOutcome.error:
        messenger.showSnackBar(SnackBar(content: Text(l.settingsUnlockError)));
    }
  }

  Future<void> _pickLockTimeout(AppLockController lock) async {
    final chosen = await showDialog<Duration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.settingsLockAfter),
        children: [
          for (final d in kAppLockTimeoutChoices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: ListTile(
                leading: Icon(
                    d == lock.timeout ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(_lockTimeoutLabel(context.l10n, d)),
              ),
            ),
        ],
      ),
    );
    if (chosen != null) await lock.setTimeout(chosen);
  }

  Widget _vocabTile(BuildContext context, String label, String title, String kind) => ListTile(
        leading: const Icon(Icons.label_outline),
        title: Text(label),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ManageVocabScreen(repo: repo, kind: kind, title: title),
        )),
      );

  Future<void> _changeHome(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    HomeLocation? picked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsChangeHomeTitle),
        content: SizedBox(
          width: 400,
          child: LocationPickerField(onSelected: (loc) => picked = loc),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.settingsSaveReenrich)),
        ],
      ),
    );
    if (confirmed == true && picked != null) {
      await repo.setHomeLocation(picked!);
      // Update the tile straight from the picked value — no DB re-read, so it shows immediately
      // even before the (slow) re-enrich below runs (backlog #7).
      if (mounted) setState(() => _home = picked);
      messenger.showSnackBar(SnackBar(content: Text(l.settingsReenriching)));
      await repo.reEnrichAll();
      messenger.showSnackBar(SnackBar(content: Text(l.settingsDone)));
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
    final l = context.l10n; // the report follows the app's language (D1)
    messenger.showSnackBar(
        SnackBar(content: Text(l.settingsBuildingReport), duration: const Duration(seconds: 2)));
    try {
      final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      // Exact glyph coverage of the embedded font, so anything it can't draw becomes "?" rather
      // than silently disappearing.
      final coverage = TtfParser(regular).charToGlyphIndexMap;
      final content = await repo.reportContent(canRender: coverage.containsKey, l10n: l);
      final bytes = await renderReportPdf(content, regular: regular, bold: bold, l10n: l);
      if (!context.mounted) return;
      await _exportBytes(context, bytes, ExportServiceFilename.pdf());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsReportFailed('$e'))));
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
        title: Text(context.l10n.settingsExportTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _ExportAction.share),
            child: ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(context.l10n.settingsShare),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _ExportAction.save),
            child: ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: Text(context.l10n.settingsSaveToDevice),
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
    final l = context.l10n;
    try {
      // The system save dialog is Megrim's own trip out, so it doesn't count as leaving (#24).
      final path = await AppLockScope.external(
          context, () => FilePicker.platform.saveFile(fileName: filename, bytes: bytes));
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text(l.settingsSaved)));
        return true;
      }
      // path == null: the user cancelled the save dialog — nothing to report.
      return false;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsSaveFailed('$e'))));
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
    final l = context.l10n;
    final result =
        await AppLockScope.external(context, () => FilePicker.platform.pickFiles(withData: true));
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    if (!context.mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsImportTitle),
        content: Text(l.settingsImportBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.settingsImportMerge)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.settingsImportReplace,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (replace == null) return;

    try {
      final r = await repo.importer.importJsonBytes(bytes, replace: replace);
      messenger.showSnackBar(
          SnackBar(content: Text(l.settingsImported(r.imported, r.skipped))));
      await repo.processEnrichmentQueue();
    } on ImportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsImportFailed(e.messageIn(l)))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsImportFailed('$e'))));
    }
  }

  Future<void> _launch(BuildContext context, String url) async {
    // Launch directly rather than gating on canLaunchUrl(): a web ACTION_VIEW is exempt from
    // Android 11+ package-visibility, whereas canLaunchUrl() needs the <queries> browser intent
    // declared in AndroidManifest and returns false without it — the old cause of a silent no-op.
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      final opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('no handler for $url');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsCouldNotOpen(url))));
    }
  }

  Future<void> _about(BuildContext context) async {
    final theme = Theme.of(context);
    final l = context.l10n;
    showAboutDialog(
      context: context,
      applicationName: 'Megrim',
      applicationVersion: kAppVersion,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/logo.png', width: 56, height: 56),
      ),
      applicationLegalese: l.settingsAboutLegalese(l.legalWeatherAttribution),
      children: [
        const SizedBox(height: 12),
        Text(l.legalAppTitle, style: theme.textTheme.titleMedium),
        Text(l.legalAppSubtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 12),
        Text(l.legalShortDescription,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(l.legalFullDescription),
        const Divider(height: 24),
        Text(l.legalPrivacySummary),
        const SizedBox(height: 12),
        Text(l.legalMedicalDisclaimer),
        // Community translations: English is the version that counts for the legal wording.
        if (!l.localeName.startsWith('en')) ...[
          const SizedBox(height: 12),
          Text(l.legalTranslationNote, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// "Never" / "Today" / "Yesterday" / "12 days ago", from [BackupStatus.daysSince].
String _backupAge(AppLocalizations l, int? days) => switch (days) {
      null => l.settingsBackupNever,
      0 => l.settingsBackupToday,
      1 => l.settingsBackupYesterday,
      _ => l.settingsBackupDaysAgo(days),
    };

/// "Off" / "Every 30 days", for the backup subtitle and the interval picker.
String _reminderLabel(AppLocalizations l, int days) =>
    days <= kBackupReminderOff ? l.settingsOff : l.settingsBackupEvery(days);

/// "Immediately" / "After 1 minute" / "After 5 minutes", for the app lock timeout.
String _lockTimeoutLabel(AppLocalizations l, Duration d) =>
    d == Duration.zero ? l.settingsLockImmediately : l.settingsLockAfterMinutes(d.inMinutes);

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
