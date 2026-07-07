import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native (Android) SQLite connection. There is no web entry point (SPEC §2).
QueryExecutor openConnection() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'megrim.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
