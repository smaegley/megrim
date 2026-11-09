/// Parses a decimal typed by the user, accepting a comma as the decimal separator as well as a
/// point: "7,5" and "7.5" both read as 7.5. Many locales (and their decimal keypads) write a comma,
/// and `double.tryParse` alone rejects it, so the value was silently not saved.
/// Returns null for empty or unparseable text.
double? parseDecimalInput(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return double.tryParse(t.replaceAll(',', '.'));
}
