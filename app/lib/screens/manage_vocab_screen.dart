import 'package:flutter/material.dart';

import '../repositories/megrim_repository.dart';

/// Manage a vocabulary list (SPEC §3.4): add / rename / delete. Renames do NOT rewrite history.
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

  Future<void> _add() async {
    final value = await _prompt('Add ${widget.title.toLowerCase()}');
    if (value != null && value.isNotEmpty) {
      await widget.repo.addVocab(widget.kind, value);
      await _load();
    }
  }

  Future<void> _rename(String old) async {
    final value = await _prompt('Rename', initial: old);
    if (value != null && value.isNotEmpty && value != old) {
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
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage ${widget.title.toLowerCase()}')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: ListView(
        children: [
          for (final v in _values)
            ListTile(
              title: Text(v),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit), onPressed: () => _rename(v)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(v)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
