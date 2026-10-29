import '../database/database.dart' show MedClass;

/// Shared wording and rules for medication classes and the overuse notice (backlog #18), so
/// Settings, Event Detail, Analytics and the report agree. Limits are ICHD-3 8.2 (checked against
/// ichd-3.org 2026-10-29); docs/METHODS.md explains how they are applied.

/// Short names, as the class picker and the Analytics card show them.
const Map<String, String> kMedClassLabels = {
  MedClass.triptan: 'Triptan',
  MedClass.ergot: 'Ergot',
  MedClass.opioid: 'Opioid',
  MedClass.combinationAnalgesic: 'Combination pain reliever',
  MedClass.simpleAnalgesic: 'Simple pain reliever',
  MedClass.gepant: 'Gepant',
  MedClass.ditan: 'Ditan',
  MedClass.antiemetic: 'Anti-nausea',
  MedClass.other: 'Other',
};

/// Examples under each choice in the picker. No brand names: the app ships no drug database
/// (SPEC open question 4), and these are only there to tell the classes apart.
const Map<String, String> kMedClassExamples = {
  MedClass.triptan: 'sumatriptan, rizatriptan, zolmitriptan…',
  MedClass.ergot: 'ergotamine, dihydroergotamine',
  MedClass.opioid: 'codeine, tramadol, oxycodone…',
  MedClass.combinationAnalgesic: 'a pain reliever combined with codeine, caffeine or butalbital',
  MedClass.simpleAnalgesic: 'paracetamol (acetaminophen), ibuprofen, naproxen, aspirin…',
  MedClass.gepant: 'ubrogepant, rimegepant, zavegepant',
  MedClass.ditan: 'lasmiditan',
  MedClass.antiemetic: 'metoclopramide, ondansetron, domperidone…',
  MedClass.other: 'anything else',
};

/// Days per month at which ICHD-3 8.2.1–8.2.5 set the reference level for each class. Classes
/// not listed (gepant, ditan, antiemetic, other, unclassified) never raise the notice.
const Map<String, int> kOveruseDaysPerMonth = {
  MedClass.ergot: 10, // 8.2.1
  MedClass.triptan: 10, // 8.2.2
  MedClass.simpleAnalgesic: 15, // 8.2.3 (all non-opioid analgesics are one class)
  MedClass.opioid: 10, // 8.2.4
  MedClass.combinationAnalgesic: 10, // 8.2.5
};

/// ICHD-3 8.2.6: two or more of the classes above, none at its own level, on this many days in
/// total (days on which any of them was taken, so two on one day count once).
const int kMixedOveruseDaysPerMonth = 10;

/// ICHD-3 asks for regular use over more than 3 months; the notice needs each of the last 3
/// complete calendar months to reach a level.
const int kOveruseMonths = 3;

bool isOveruseClass(String? medClass) => kOveruseDaysPerMonth.containsKey(medClass);

/// The key under which medications without a class are counted.
const String kUnclassified = 'unclassified';

/// The reason a month reached a reference level: a [MedClass] value, or this for ICHD-3 8.2.6.
const String kMixedClasses = 'mixed';

/// "Triptan", or "No class set" for null and [kUnclassified].
String medClassName(String? key) =>
    key == null || key == kUnclassified ? 'No class set' : kMedClassLabels[key] ?? key;

/// The overuse notice (backlog #18), as the Analytics card and the report word it. It states the
/// counts and the reference level and suggests a doctor; it never says the user has
/// medication-overuse headache and never tells them to stop or change a medication.
const String kOveruseNoticeTitle = 'Medication days at a reference level';

const String kOveruseNoticeBody =
    'In each of the last 3 complete months, your days with acute medication reached a level that '
    'headache guidelines (ICHD-3) use when looking at medication-overuse headache, where frequent '
    'use of acute medication can make headaches more frequent. This is a count of what you '
    'logged, not a diagnosis. Don\'t change how you take a medication because of it; it may be '
    'worth discussing with your doctor.';

/// `yyyy-MM-dd` for a calendar date (preventive start/stop, schema v5).
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Inverse of [isoDay], as a local-flagged midnight; null if [s] isn't a date.
DateTime? parseIsoDay(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}
