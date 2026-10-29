import 'dart:convert';

import 'med_entry.dart';
import 'relief_entry.dart';

/// Helpers for the JSON-encoded TEXT columns on migraine_events
/// (location_head, triggers_suspected, foods_notable, meds_taken, relief_tried).

List<String> decodeStringList(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final v = jsonDecode(raw);
    if (v is List) return v.map((e) => e.toString()).toList();
  } catch (_) {}
  return const [];
}

String? encodeStringList(List<String> values) {
  if (values.isEmpty) return null;
  return jsonEncode(values);
}

List<MedEntry> decodeMeds(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final v = jsonDecode(raw);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => MedEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  } catch (_) {}
  return const [];
}

String? encodeMeds(List<MedEntry> meds) {
  if (meds.isEmpty) return null;
  return jsonEncode(meds.map((m) => m.toJson()).toList());
}

List<ReliefEntry> decodeRelief(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final v = jsonDecode(raw);
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => ReliefEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  } catch (_) {}
  return const [];
}

String? encodeRelief(List<ReliefEntry> relief) {
  if (relief.isEmpty) return null;
  return jsonEncode(relief.map((r) => r.toJson()).toList());
}
