import 'package:flutter/material.dart';

import 'app.dart';
import 'database/database.dart';
import 'repositories/megrim_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = MegrimDatabase();
  final repo = MegrimRepository(db: db);
  runApp(MegrimApp(repo: repo));
}
