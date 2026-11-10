import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;

/// Runs before every test file: loads the date names for every locale, as `main()` does in the
/// app (docs/TRANSLATIONS.md), and sets up the binding so code outside widgets (the PDF report)
/// can read the phone's locales the way it does in the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await testMain();
}
