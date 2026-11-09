import 'package:flutter/material.dart';

import '../database/database.dart';
import '../l10n/formats.dart';
import '../l10n/l10n.dart';
import '../models/medications.dart';
import '../repositories/megrim_repository.dart';
import '../widgets/med_class_picker.dart';

/// Settings › Medications (backlog #18, #19): the acute medications learned from entries, each
/// with its class, and the preventive medications, each with start and stop dates. Renames do
/// NOT rewrite history (SPEC §3.4); the new name takes the class, and the old one keeps it for
/// the entries that still carry it.
class MedicationsScreen extends StatefulWidget {
  final MegrimRepository repo;
  const MedicationsScreen({super.key, required this.repo});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<String> _acute = const [];
  Map<String, String> _classes = const {};
  List<PreventiveRegimen> _preventives = const [];
  bool _loaded = false;

  MegrimRepository get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final acute = await repo.vocab(VocabKind.medication);
    final classes = await repo.medicationClasses();
    final preventives = await repo.preventives();
    if (!mounted) return;
    setState(() {
      _acute = acute;
      _classes = classes;
      _preventives = preventives;
      _loaded = true;
    });
  }

  Future<void> _addAcute() async {
    final name = await _prompt(context.l10n.entryAddMedication);
    if (name == null || name.isEmpty || !mounted) return;
    await repo.addVocab(VocabKind.medication, name);
    if (!mounted) return;
    if (await repo.medicationClassOf(name) == null && mounted) {
      final picked = await showMedClassPicker(context, name: name);
      if (picked != null) await repo.setMedicationClass(name, picked.cls);
    }
    await _load();
  }

  Future<void> _setClass(String name) async {
    final picked = await showMedClassPicker(context, name: name, current: _classes[name]);
    if (picked == null) return;
    await repo.setMedicationClass(name, picked.cls);
    await _load();
  }

  Future<void> _renameAcute(String old) async {
    final value = await _prompt(context.l10n.medsRename, initial: old);
    if (value != null && value.isNotEmpty && value != old) {
      await repo.renameVocab(VocabKind.medication, old, value);
      await _load();
    }
  }

  Future<void> _deleteAcute(String value) async {
    await repo.deleteVocab(VocabKind.medication, value);
    await _load();
  }

  Future<void> _editPreventive([PreventiveRegimen? p]) async {
    final result = await showDialog<_PreventiveResult>(
      context: context,
      builder: (_) => _PreventiveDialog(initial: p),
    );
    if (result == null) return;
    if (result.delete) {
      await repo.deletePreventive(p!.id);
    } else {
      await repo.savePreventive(
        id: p?.id,
        name: result.name,
        dose: result.dose,
        startedOn: isoDay(result.startedOn),
        stoppedOn: result.stoppedOn == null ? null : isoDay(result.stoppedOn!),
        notes: result.notes,
      );
    }
    await _load();
  }

  Future<String?> _prompt(String title, {String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(MaterialLocalizations.of(context).saveButtonLabel)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    Widget header(String title, String subtitle) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.medsTitle)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                header(l.medsAcuteTitle, l.medsAcuteHint),
                for (final name in _acute)
                  ListTile(
                    title: Text(name),
                    subtitle: Text(medClassName(l, _classes[name])),
                    onTap: () => _setClass(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: l.medsRename,
                            onPressed: () => _renameAcute(name)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                            onPressed: () => _deleteAcute(name)),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton.icon(
                      onPressed: _addAcute,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.entryAddMedication),
                    ),
                  ),
                ),
                const Divider(),
                header(l.medsPreventiveTitle, l.medsPreventiveHint),
                for (final p in _preventives)
                  ListTile(
                    title: Text(p.dose == null ? p.name : '${p.name} · ${p.dose}'),
                    subtitle: Text(preventiveSpan(p, l)),
                    onTap: () => _editPreventive(p),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton.icon(
                      onPressed: _editPreventive,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.medsAddPreventive),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

/// "Since 1 Mar 2026" or "1 Mar 2026 – 30 Sep 2026", in [l]'s language (English by default).
String preventiveSpan(PreventiveRegimen p, [AppLocalizations? l]) {
  final l10n = l ?? englishL10n;
  final f = Formats.forL10n(l10n);
  String day(String s) {
    final d = parseIsoDay(s);
    return d == null ? s : f.date(d);
  }

  return p.stoppedOn == null
      ? l10n.medsSince(day(p.startedOn))
      : l10n.medsSpan(day(p.startedOn), day(p.stoppedOn!));
}

class _PreventiveResult {
  final bool delete;
  final String name;
  final String? dose;
  final DateTime startedOn;
  final DateTime? stoppedOn;
  final String? notes;
  const _PreventiveResult({
    this.delete = false,
    required this.name,
    this.dose,
    required this.startedOn,
    this.stoppedOn,
    this.notes,
  });
}

class _PreventiveDialog extends StatefulWidget {
  final PreventiveRegimen? initial;
  const _PreventiveDialog({required this.initial});

  @override
  State<_PreventiveDialog> createState() => _PreventiveDialogState();
}

class _PreventiveDialogState extends State<_PreventiveDialog> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _notes;
  late DateTime _startedOn;
  DateTime? _stoppedOn;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _dose = TextEditingController(text: p?.dose ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    final now = DateTime.now();
    _startedOn = parseIsoDay(p?.startedOn) ?? DateTime(now.year, now.month, now.day);
    _stoppedOn = parseIsoDay(p?.stoppedOn);
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(now.year - 40),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = Formats.of(context);
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.initial == null ? l.medsAddPreventive : l.medsEditPreventive),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.initial == null,
                decoration:
                    InputDecoration(labelText: l.entryMedName, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dose,
                decoration: InputDecoration(
                    labelText: l.entryDose,
                    hintText: l.medsPreventiveDoseHint,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(l.medsStarted),
                subtitle: Text(f.date(_startedOn)),
                onTap: () async {
                  final d = await _pickDate(_startedOn);
                  if (d == null) return;
                  setState(() {
                    _startedOn = d;
                    if (_stoppedOn != null && _stoppedOn!.isBefore(d)) _stoppedOn = d;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.medsStillTaking),
                value: _stoppedOn == null,
                onChanged: (on) async {
                  if (on) {
                    setState(() => _stoppedOn = null);
                    return;
                  }
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final d = await _pickDate(today.isBefore(_startedOn) ? _startedOn : today,
                      first: _startedOn);
                  if (d != null) setState(() => _stoppedOn = d);
                },
              ),
              if (_stoppedOn != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_busy),
                  title: Text(l.medsStopped),
                  subtitle: Text(f.date(_stoppedOn!)),
                  onTap: () async {
                    final d = await _pickDate(_stoppedOn!, first: _startedOn);
                    if (d != null) setState(() => _stoppedOn = d);
                  },
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: InputDecoration(
                    labelText: l.medsNotes,
                    hintText: l.medsNotesHint,
                    border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.pop(
                context, _PreventiveResult(delete: true, name: '', startedOn: _startedOn)),
            child: Text(MaterialLocalizations.of(context).deleteButtonTooltip),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
            Navigator.pop(
              context,
              _PreventiveResult(
                name: name,
                dose: opt(_dose),
                startedOn: _startedOn,
                stoppedOn: _stoppedOn,
                notes: opt(_notes),
              ),
            );
          },
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
