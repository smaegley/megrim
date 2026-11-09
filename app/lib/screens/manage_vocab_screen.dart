import 'package:flutter/material.dart';

import '../l10n/data_labels.dart';
import '../l10n/l10n.dart';
import '../repositories/megrim_repository.dart';

/// Manage a vocabulary list (SPEC §3.4): add / rename / delete. Renames do NOT rewrite history.
///
/// Values are stored in English for the defaults and as typed otherwise; the list shows them with
/// [dataLabel] (docs/TRANSLATIONS.md, "Data stays English").
class ManageVocabScreen extends StatefulWidget {
  final MegrimRepository repo;
  final String kind;
  final String title;
  const ManageVocabScreen(
      {super.key, required this.repo, required this.kind, required this.title});

  @override
  State<ManageVocabScreen> createState() => _ManageVocabScreenState();
}

class _ManageVocabScreenState extends State<ManageVocabScreen> {
  List<String> _values = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await widget.repo.vocab(widget.kind);
    if (mounted) setState(() => _values = v);
  }

  /// The list's name as it reads mid-sentence ("Add suspected triggers"). Lowercased in English
  /// only: other languages (German nouns, for one) keep the title's capitals.
  String get _item {
    final l = context.l10n;
    return l.localeName.startsWith('en') ? widget.title.toLowerCase() : widget.title;
  }

  Future<void> _add() async {
    final value = await _prompt(context.l10n.vocabAddTitle(_item));
    if (value != null && value.isNotEmpty) {
      await widget.repo.addVocab(widget.kind, value);
      await _load();
    }
  }

  /// The field starts with the name as displayed. Saving it unchanged keeps the stored value (a
  /// default stays its English value); a real edit stores the new text as the user's own.
  Future<void> _rename(String old) async {
    final shown = dataLabel(context.l10n, old);
    final value = await _prompt(context.l10n.medsRename, initial: shown);
    if (value != null && value.isNotEmpty && value != shown && value != old) {
      await widget.repo.renameVocab(widget.kind, old, value);
      await _load();
    }
  }

  Future<void> _delete(String value) async {
    await widget.repo.deleteVocab(widget.kind, value);
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
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.vocabManageTitle(_item))),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: l.vocabAddTitle(_item),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final v in _values)
            ListTile(
              title: Text(dataLabel(l, v)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: l.medsRename,
                      onPressed: () => _rename(v)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                      onPressed: () => _delete(v)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
