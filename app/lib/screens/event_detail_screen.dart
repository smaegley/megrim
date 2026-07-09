import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../models/home_location.dart';
import '../models/json_fields.dart';
import '../models/med_entry.dart';
import '../repositories/megrim_repository.dart';
import '../widgets/location_picker.dart';
import '../widgets/severity_badge.dart' show StatusColors;
import 'manage_vocab_screen.dart';

/// Event Detail (SPEC §4.4): edit all fields; chips from user vocab; shows the computed
/// enrichment. Start/end time and the recorded location are editable so an entry can be recreated
/// after the fact (review item #4). Saving re-enqueues enrichment (date/location may have changed).
class EventDetailScreen extends StatefulWidget {
  final MegrimRepository repo;
  final String eventId;
  const EventDetailScreen({super.key, required this.repo, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  MigraineEvent? _event;
  DerivedFactor? _derived;
  List<String> _triggerVocab = const [];
  List<String> _locationVocab = const [];
  List<String> _medVocab = const [];

  DateTime _startedAt = DateTime.now();
  DateTime? _endedAt;
  double? _geoLat;
  double? _geoLon;
  String? _geoLabel;
  int? _severity;
  bool? _aura;
  int? _stress;
  final _sleep = TextEditingController();
  final _notes = TextEditingController();
  final Set<String> _locations = {};
  final Set<String> _triggers = {};
  final List<MedEntry> _meds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sleep.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final e = await widget.repo.getEvent(widget.eventId);
    final d = await widget.repo.getDerived(widget.eventId);
    final triggers = await widget.repo.vocab(VocabKind.trigger);
    final locations = await widget.repo.vocab(VocabKind.headLocation);
    final meds = await widget.repo.vocab(VocabKind.medication);
    if (!mounted || e == null) return;
    setState(() {
      _event = e;
      _derived = d;
      _triggerVocab = triggers;
      _locationVocab = locations;
      _medVocab = meds;
      _startedAt = e.startedAt.toLocal();
      _endedAt = e.endedAt?.toLocal();
      _geoLat = e.geoLat;
      _geoLon = e.geoLon;
      _geoLabel = e.geoLabel;
      _severity = e.severity;
      _aura = e.auraPresent;
      _stress = e.stressLevel;
      _sleep.text = e.sleepHoursPrior?.toString() ?? '';
      _notes.text = e.notes ?? '';
      _locations
        ..clear()
        ..addAll(decodeStringList(e.locationHead));
      _triggers
        ..clear()
        ..addAll(decodeStringList(e.triggersSuspected));
      _meds
        ..clear()
        ..addAll(decodeMeds(e.medsTaken));
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_endedAt != null && _endedAt!.isBefore(_startedAt)) {
      messenger.showSnackBar(
          const SnackBar(content: Text('End time must be after the start time.')));
      return;
    }
    await widget.repo.updateEvent(MigraineEventsCompanion(
      id: Value(widget.eventId),
      startedAt: Value(_startedAt.toUtc()),
      endedAt: Value(_endedAt?.toUtc()),
      severity: Value(_severity),
      auraPresent: Value(_aura),
      stressLevel: Value(_stress),
      sleepHoursPrior: Value(double.tryParse(_sleep.text)),
      notes: Value(_notes.text.isEmpty ? null : _notes.text),
      locationHead: Value(encodeStringList(_locations.toList())),
      triggersSuspected: Value(encodeStringList(_triggers.toList())),
      medsTaken: Value(encodeMeds(_meds)),
      geoLat: Value(_geoLat),
      geoLon: Value(_geoLon),
      geoLabel: Value(_geoLabel),
    ));
    // Date and/or location may change enrichment inputs — re-enqueue (local, not an API POST).
    await widget.repo.enrichment.enqueue(widget.eventId);
    widget.repo.processEnrichmentQueue().catchError((_) {});
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This permanently removes the migraine and its computed factors.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final removed = await widget.repo.deleteEvent(widget.eventId);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (removed != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Entry deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => widget.repo.restoreEvent(removed.event, removed.derived),
        ),
      ));
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final base = isStart ? _startedAt : (_endedAt ?? _startedAt);
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? base.hour,
      time?.minute ?? base.minute,
    );
    setState(() {
      if (isStart) {
        _startedAt = picked;
      } else {
        _endedAt = picked;
      }
    });
  }

  Future<void> _editLocation() async {
    HomeLocation? picked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recorded location'),
        content: SizedBox(
          width: 400,
          child: LocationPickerField(
            initial: (_geoLat != null && _geoLon != null)
                ? HomeLocation(lat: _geoLat!, lon: _geoLon!, label: _geoLabel ?? '')
                : null,
            onSelected: (loc) => picked = loc,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use location')),
        ],
      ),
    );
    if (confirmed == true && picked != null) {
      setState(() {
        _geoLat = picked!.lat;
        _geoLon = picked!.lon;
        _geoLabel = picked!.label;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_event == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete entry',
            onPressed: _delete,
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dateTimeTile(
            label: 'Started',
            value: _startedAt,
            onTap: () => _pickDateTime(isStart: true),
          ),
          _dateTimeTile(
            label: 'Ended',
            value: _endedAt,
            onTap: () => _pickDateTime(isStart: false),
            onClear: _endedAt == null ? null : () => setState(() => _endedAt = null),
            emptyHint: 'ongoing — tap to set',
          ),
          _locationTile(),
          const Divider(height: 24),

          Text('Severity: ${_severity ?? '—'} / 10'),
          Slider(
            value: (_severity ?? 5).toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '${_severity ?? 5}',
            onChanged: (v) => setState(() => _severity = v.round()),
          ),

          _sectionHeader('Head location', VocabKind.headLocation),
          _chips(_locationVocab, _locations),

          const SizedBox(height: 16),
          const Text('Aura'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Yes')),
              ButtonSegment(value: 0, label: Text('No')),
              ButtonSegment(value: -1, label: Text('Unknown')),
            ],
            selected: {_aura == null ? -1 : (_aura! ? 1 : 0)},
            onSelectionChanged: (s) => setState(() {
              final v = s.first;
              _aura = v == -1 ? null : v == 1;
            }),
          ),

          _sectionHeader('Suspected triggers', VocabKind.trigger),
          _chips(_triggerVocab, _triggers),

          _sectionHeader('Medications', VocabKind.medication),
          _medsSection(),

          const SizedBox(height: 16),
          TextField(
            controller: _sleep,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Sleep hours (prior night)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('Stress level: ${_stress ?? '—'} / 5'),
          Slider(
            value: (_stress ?? 3).toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: '${_stress ?? 3}',
            onChanged: (v) => setState(() => _stress = v.round()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
          ),

          const Divider(height: 32),
          _enrichmentCard(),
        ],
      ),
    );
  }

  Widget _dateTimeTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? emptyHint,
  }) {
    final df = DateFormat('EEE d MMM yyyy, HH:mm');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(label),
      subtitle: Text(value != null ? df.format(value) : (emptyHint ?? '—')),
      trailing: onClear != null
          ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear (mark ongoing)',
              onPressed: onClear,
            )
          : const Icon(Icons.edit_outlined),
      onTap: onTap,
    );
  }

  Widget _locationTile() {
    final subtitle = (_geoLabel != null && _geoLabel!.isNotEmpty)
        ? '$_geoLabel'
            '${_geoLat != null && _geoLon != null ? ' (${_geoLat!.toStringAsFixed(2)}, ${_geoLon!.toStringAsFixed(2)})' : ''}'
        : (_geoLat != null && _geoLon != null)
            ? '(${_geoLat!.toStringAsFixed(2)}, ${_geoLon!.toStringAsFixed(2)})'
            : 'Not set — tap to add';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_outlined),
      title: const Text('Recorded location'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.edit_outlined),
      onTap: _editLocation,
    );
  }

  Widget _sectionHeader(String title, String kind) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ManageVocabScreen(repo: widget.repo, kind: kind, title: title),
                ));
                await _load();
              },
              child: const Text('Manage'),
            ),
          ],
        ),
      );

  Widget _chips(List<String> vocab, Set<String> selected) {
    // Chips shown = vocab ∪ values present on the event (SPEC §3.4).
    final all = {...vocab, ...selected}.toList();
    return Wrap(
      spacing: 8,
      children: [
        for (final v in all)
          FilterChip(
            label: Text(v),
            selected: selected.contains(v),
            onSelected: (on) => setState(() {
              if (on) {
                selected.add(v);
              } else {
                selected.remove(v);
              }
            }),
          ),
      ],
    );
  }

  /// Medications taken for this event: a list of rich entries (name + optional dose, time,
  /// "helped?"), plus an add button. Backed by the `medication` vocab, which is learned from
  /// whatever names are entered here (SPEC §3.4). Writes the `meds_taken` JSON that export/CSV emit.
  Widget _medsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _meds.length; i++) _medTile(i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _editMed(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add medication'),
          ),
        ),
      ],
    );
  }

  Widget _medTile(int index) {
    final m = _meds[index];
    final parts = <String>[
      if (m.dose != null && m.dose!.isNotEmpty) m.dose!,
      if (m.time != null) _fmtMedTime(m.time!),
    ];
    final subtitle = parts.join(' · ');
    // Fixed status palette (works on both light/dark surfaces; the icon carries the meaning);
    // unknown uses a theme-muted tone.
    final (helpIcon, helpColor) = switch (m.helped) {
      true => (Icons.thumb_up_outlined, StatusColors.good),
      false => (Icons.thumb_down_outlined, StatusColors.serious),
      null => (Icons.help_outline, Theme.of(context).colorScheme.onSurfaceVariant),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(helpIcon, color: helpColor),
        title: Text(m.name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Remove medication',
          onPressed: () => setState(() => _meds.removeAt(index)),
        ),
        onTap: () => _editMed(index: index),
      ),
    );
  }

  /// Format an ISO-8601 UTC med time for display in the device's local zone.
  String _fmtMedTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('HH:mm').format(dt.toLocal());
  }

  /// Add (index null) or edit an existing medication entry. New names are learned into the
  /// `medication` vocab so they appear as suggestions next time.
  Future<void> _editMed({int? index}) async {
    final result = await showDialog<MedEntry>(
      context: context,
      builder: (_) => _MedEditDialog(
        vocab: _medVocab,
        initial: index == null ? null : _meds[index],
        eventDay: _startedAt,
      ),
    );
    if (result == null || !mounted) return;
    if (result.name.trim().isEmpty) return;
    if (!_medVocab.contains(result.name)) {
      await widget.repo.addVocab(VocabKind.medication, result.name);
      if (!mounted) return;
      setState(() => _medVocab = [..._medVocab, result.name]);
    }
    setState(() {
      if (index == null) {
        _meds.add(result);
      } else {
        _meds[index] = result;
      }
    });
  }

  Widget _enrichmentCard() {
    final d = _derived;
    if (d == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.hourglass_empty),
          title: Text('Enrichment pending'),
          subtitle: Text('Weather and astronomy will be added when online.'),
        ),
      );
    }
    String? f(num? v, String unit) => v == null ? null : '$v$unit';
    final rows = <String, String?>{
      'Season': d.season,
      'Time of day': d.timeOfDayBucket,
      'Daylight': f(d.daylightHours, ' h'),
      'Moon': d.moonPhase,
      'Temp': f(d.tempC, ' °C'),
      'Humidity': f(d.humidityPct, ' %'),
      'Pressure': f(d.pressureHpa, ' hPa'),
      'Pressure Δ 24h': f(d.pressureDelta24h, ' hPa'),
      'AQI': d.aqi?.toString(),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enrichment', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              if (entry.value != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(entry.key), Text(entry.value!)],
                  ),
                ),
            if (d.enrichError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(d.enrichError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add/edit a single medication: name (chosen from vocab or typed free), optional dose, optional
/// time, and a tri-state "helped?". Returns the built [MedEntry] via Navigator.pop, or null on cancel.
class _MedEditDialog extends StatefulWidget {
  final List<String> vocab;
  final MedEntry? initial;

  /// The event's start day, used to anchor a picked time-of-day to a concrete date.
  final DateTime eventDay;

  const _MedEditDialog({
    required this.vocab,
    required this.initial,
    required this.eventDay,
  });

  @override
  State<_MedEditDialog> createState() => _MedEditDialogState();
}

class _MedEditDialogState extends State<_MedEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  TimeOfDay? _time;
  bool? _helped;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(text: m?.dose ?? '');
    _helped = m?.helped;
    final iso = m?.time;
    if (iso != null) {
      final dt = DateTime.tryParse(iso);
      if (dt != null) _time = TimeOfDay.fromDateTime(dt.toLocal());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  /// Combine the picked time-of-day with the event's date, return as an ISO-8601 UTC string.
  String? _isoTime() {
    if (_time == null) return null;
    final d = widget.eventDay;
    return DateTime(d.year, d.month, d.day, _time!.hour, _time!.minute)
        .toUtc()
        .toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add medication' : 'Edit medication'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name: free text, with previously-used meds as autocomplete suggestions.
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _name.text),
                optionsBuilder: (value) {
                  final q = value.text.trim().toLowerCase();
                  if (q.isEmpty) return widget.vocab;
                  return widget.vocab
                      .where((v) => v.toLowerCase().contains(q));
                },
                onSelected: (v) => _name.text = v,
                fieldViewBuilder: (context, controller, focusNode, _) {
                  // Keep our _name in sync with the internal Autocomplete controller.
                  controller.text = _name.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: widget.initial == null,
                    decoration: const InputDecoration(
                        labelText: 'Name', border: OutlineInputBorder()),
                    onChanged: (v) => _name.text = v,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dose,
                decoration: const InputDecoration(
                    labelText: 'Dose (optional)',
                    hintText: 'e.g. 400 mg',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('Time taken'),
                subtitle: Text(_time == null ? 'Not set' : _time!.format(context)),
                trailing: _time == null
                    ? const Icon(Icons.edit_outlined)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear time',
                        onPressed: () => setState(() => _time = null),
                      ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time ?? TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const SizedBox(height: 8),
              const Text('Helped?'),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Yes')),
                  ButtonSegment(value: 0, label: Text('No')),
                  ButtonSegment(value: -1, label: Text('Unknown')),
                ],
                selected: {_helped == null ? -1 : (_helped! ? 1 : 0)},
                onSelectionChanged: (s) => setState(() {
                  final v = s.first;
                  _helped = v == -1 ? null : v == 1;
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final dose = _dose.text.trim();
            Navigator.pop(
              context,
              MedEntry(
                name: name,
                dose: dose.isEmpty ? null : dose,
                time: _isoTime(),
                helped: _helped,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
