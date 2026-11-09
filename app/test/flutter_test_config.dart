import 'dart:async';

import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;

/// Runs before every test file: loads the date names for every locale, as `main()` does in the
/// app (docs/TRANSLATIONS.md).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting();
  await testMain();
}
