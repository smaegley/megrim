import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../models/json_fields.dart';
import '../repositories/megrim_repository.dart';
import 'manage_vocab_screen.dart';

/// The optional details of a "No migraine today" check-in (backlog #16): the same self-report
/// fields as an entry, so they have a clear-day baseline. The check-in itself is saved before this
/// opens (one tap on Quick Log or the calendar); this only adds to it, and can remove it.
class CheckinScreen extends StatefulWidget {
  final MegrimRepository repo;

  /// The check-in's local calendar date.
  final DateTime day;
  const CheckinScreen({super.key, required this.repo, required this.day});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  List<String> _triggerVocab = const [];
  final Set<String> _triggers = {};
  final List<String> _foods = [];
  final _sleep = TextEditingController();
  int? _stress;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sleep.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final vocab = await widget.repo.vocab(VocabKind.trigger);
    final c = await widget.repo.checkinOn(widget.day);
    if (!mounted) return;
    setState(() {
      _triggerVocab = vocab;
      if (!_loaded && c != null) {
        _triggers.addAll(decodeStringList(c.triggersSuspected));
        _foods.addAll(decodeStringList(c.foodsNotable));
        _sleep.text = c.sleepHoursPrior?.toString() ?? '';
        _stress = c.stressLevel;
      }
      _loaded = true;
    });
  }

  Future<void> _save() async {
    await widget.repo.saveCheckinDetails(
      widget.day,
      triggers: _triggers.toList(),
      sleepHours: double.tryParse(_sleep.text.trim()),
      stress: _stress,
      foods: _foods,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = await widget.repo.removeCheckin(widget.day);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (removed != null) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Check-in removed'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => widget.repo.restoreCheckins([removed]),
          ),
        ),
      );
    }
  }

  Future<void> _addFood() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add food'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. chocolate, red wine'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (value != null && value.isNotEmpty && !_foods.contains(value)) {
      setState(() => _foods.add(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget header(String title, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          ?trailing,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('No migraine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove check-in',
            onPressed: _remove,
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  DateFormat('EEEE d MMMM yyyy').format(widget.day),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'All optional. Recording the same things on clear days as on migraine days is '
                  'what lets Analytics compare the two.',
                  style: theme.textTheme.bodySmall,
                ),
                header(
                  'Possible triggers',
                  trailing: TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ManageVocabScreen(
                            repo: widget.repo,
                            kind: VocabKind.trigger,
                            title: 'Suspected triggers',
                          ),
                        ),
                      );
                      await _load();
                    },
                    child: const Text('Manage'),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in {..._triggerVocab, ..._triggers})
                      FilterChip(
                        label: Text(v),
                        selected: _triggers.contains(v),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _triggers.add(v);
                          } else {
                            _triggers.remove(v);
                          }
                        }),
                      ),
                  ],
                ),
                header('Foods notable'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _foods.length; i++)
                      InputChip(
                        label: Text(_foods[i]),
                        onDeleted: () => setState(() => _foods.removeAt(i)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Add food'),
                      onPressed: _addFood,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sleep,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Sleep hours (prior night)',
                    border: OutlineInputBorder(),
                  ),
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
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
    );
  }
}
