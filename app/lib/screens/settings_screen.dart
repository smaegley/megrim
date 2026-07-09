import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../database/database.dart';
import '../legal.dart';
import '../models/home_location.dart';
import '../repositories/megrim_repository.dart';
import '../services/import_service.dart';
import '../widgets/location_picker.dart';
import 'manage_vocab_screen.dart';

/// Settings (SPEC §4.6): home location, vocab management, export/import, donate, About.
class SettingsScreen extends StatelessWidget {
  final MegrimRepository repo;
  const SettingsScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home location'),
            subtitle: FutureBuilder<HomeLocation?>(
              future: repo.homeLocation,
              builder: (context, snap) => Text(snap.data?.label ?? '—'),
            ),
            onTap: () => _changeHome(context),
          ),
          const Divider(),
          _vocabTile(context, 'Triggers', VocabKind.trigger),
          _vocabTile(context, 'Head locations', VocabKind.headLocation),
          _vocabTile(context, 'Medications', VocabKind.medication),
          const Divider(),
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
            leading: const Icon(Icons.download),
            title: const Text('Import (JSON)'),
            onTap: () => _import(context),
          ),
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
      messenger.showSnackBar(
          const SnackBar(content: Text('Re-enriching entries…')));
      await repo.reEnrichAll();
      messenger.showSnackBar(const SnackBar(content: Text('Done.')));
    }
  }

  Future<void> _exportJson(BuildContext context) async {
    final json = await repo.exporter.toJsonString();
    final name = ExportServiceFilename.json();
    await _shareText(json, name);
  }

  Future<void> _exportCsv(BuildContext context) async {
    final csv = await repo.exporter.toCsv();
    final name = ExportServiceFilename.csv();
    await _shareText(csv, name);
  }

  Future<void> _shareText(String content, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final raw = String.fromCharCodes(bytes);

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
      final r = await repo.importer.importJsonString(raw, replace: replace);
      messenger.showSnackBar(SnackBar(
          content: Text('Imported ${r.imported}, skipped ${r.skipped}.')));
      await repo.processEnrichmentQueue();
    } on ImportException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: ${e.message}')));
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
      applicationVersion: '0.1.0',
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
  static String _name(String ext) {
    final now = DateTime.now();
    return 'megrim-export-${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.$ext';
  }
}
