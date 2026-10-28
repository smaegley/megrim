import '../database/database.dart';
import 'json_fields.dart';

/// Shared wording and rules for the schema v4 attack fields (backlog #20, #22a, #26), so History,
/// Event Detail, Analytics and the report all describe an entry the same way.

/// Whether an entry counts as a headache attack. Only an explicit "no" is headache-free; null
/// (rows from before v4, or "Not sure") counts as a headache, so old data reads as it always did.
bool hasHeadache(bool? headachePresent) => headachePresent != false;

/// The kinds of attack without headache, as the report breaks them down. Derived from what was
/// recorded, never stored, so the rule can change without a migration.
enum NoHeadacheKind { aura, vertigo, other }

/// Aura wins over vertigo when both are present: "typical aura without headache" (ICHD-3
/// 1.2.1.2) is the more specific diagnosis to point a clinician at.
NoHeadacheKind noHeadacheKind({required bool? aura, required List<String> symptoms}) {
  if (aura == true) return NoHeadacheKind.aura;
  if (symptoms.contains(kSymptomVertigo) || symptoms.contains(kSymptomDizziness)) {
    return NoHeadacheKind.vertigo;
  }
  return NoHeadacheKind.other;
}

/// "No headache · with aura", "No headache · with vertigo", or "No headache"; null for an entry
/// that counts as a headache.
String? noHeadacheLabel(MigraineEvent e) {
  if (hasHeadache(e.headachePresent)) return null;
  return switch (noHeadacheKind(aura: e.auraPresent, symptoms: decodeStringList(e.symptoms))) {
    NoHeadacheKind.aura => 'No headache · with aura',
    NoHeadacheKind.vertigo => 'No headache · with vertigo',
    NoHeadacheKind.other => 'No headache',
  };
}

/// Short labels for [EventImpact] values, as the Event Detail picker shows them.
const Map<String, String> kImpactLabels = {
  EventImpact.normal: 'Normal',
  EventImpact.reduced: 'Reduced',
  EventImpact.unable: 'Unable',
};

/// Longer wording for reading back a recorded impact (History, the report).
const Map<String, String> kImpactDescriptions = {
  EventImpact.normal: 'functioned normally',
  EventImpact.reduced: 'reduced function',
  EventImpact.unable: 'unable to function',
};

/// Shown under the Event Detail picker once a level is chosen, so the short label can't be misread
/// ("Unable" once read as "unable to stop me").
const Map<String, String> kImpactExplanations = {
  EventImpact.normal: 'Functioned normally: got through the day as usual',
  EventImpact.reduced: 'Reduced function: did less, or less well',
  EventImpact.unable: "Unable to function: couldn't do your usual activities",
};
