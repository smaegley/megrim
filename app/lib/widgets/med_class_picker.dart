import 'package:flutter/material.dart';

import '../database/database.dart' show MedClass;
import '../l10n/l10n.dart';
import '../models/medications.dart';

/// Pick a medication's class (backlog #18). Resolves to `(cls: null)` for "Not set", or to null
/// if the dialog is dismissed, so callers can tell "clear it" from "leave it".
Future<({String? cls})?> showMedClassPicker(BuildContext context,
    {required String name, String? current}) {
  return showDialog<({String? cls})>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.medClassPickerTitle(name)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            context.l10n.medClassPickerHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final c in MedClass.all) _option(context, c, current),
        _option(context, null, current),
      ],
    ),
  );
}

Widget _option(BuildContext context, String? cls, String? current) => ListTile(
      title: Text(cls == null ? context.l10n.commonNotSet : medClassLabel(context.l10n, cls)),
      subtitle: cls == null ? null : Text(medClassExamples(context.l10n, cls)),
      trailing: cls == current ? const Icon(Icons.check) : null,
      selected: cls == current,
      onTap: () => Navigator.pop(context, (cls: cls)),
    );
