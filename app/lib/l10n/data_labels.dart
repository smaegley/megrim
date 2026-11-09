import 'package:intl/intl.dart';

import '../analytics/checkins.dart'
    show kFoodFactor, kSleepBuckets, kSleepFactor, kStressBuckets, kStressFactor, kTriggerFactor;
import '../analytics/correlations.dart'
    show kDaylightBuckets, kDowLabels, kMonthLabels, kMoonOrder, kPressureBuckets;
import '../analytics/dashboard.dart' show kTimeOfDayOrder;
import '../database/database.dart'
    show kDefaultHeadLocations, kDefaultRelief, kDefaultSymptoms, kDefaultTriggers;
import '../enrichment/calendar_factors.dart' show kSeasons;
import 'formats.dart' show formatLocale;
import 'gen/app_localizations.dart';

/// Display names for values the app stores and computes in English (docs/TRANSLATIONS.md, "Data
/// stays English"). The default vocabulary, analytics factor names and their buckets are saved in
/// entries, compared as keys and written to the export, so they never change; they are
/// translated only when shown. Anything not listed here, such as a trigger the user typed, is
/// returned unchanged.
String dataLabel(AppLocalizations l, String value) {
  final f = _labels[value];
  if (f != null) return f(l);
  final dow = kDowLabels.indexOf(value);
  // 2024-01-01 was a Monday; kDowLabels starts on Monday.
  if (dow >= 0) return DateFormat.E(formatLocale(l)).format(DateTime(2024, 1, 1 + dow));
  final month = kMonthLabels.indexOf(value);
  if (month >= 0) return DateFormat.MMM(formatLocale(l)).format(DateTime(2024, month + 1));
  return _bucketLabel(l, value) ?? value;
}

/// Every English value [dataLabel] translates; a test checks each one has its own translation.
final List<String> kTranslatedDataValues = [
  ..._labels.keys,
  ...kDowLabels,
  ...kMonthLabels,
  ...kPressureBuckets,
  ...kDaylightBuckets,
  ...kSleepBuckets,
  ...kStressBuckets,
];

/// The lists [kTranslatedDataValues] must cover: the defaults the app seeds and the labels the
/// analytics produce.
final List<String> kDataValuesNeedingTranslation = [
  ...kDefaultTriggers,
  ...kDefaultHeadLocations,
  ...kDefaultSymptoms,
  ...kDefaultRelief,
  ...kSeasons,
  ...kMoonOrder,
  ...kTimeOfDayOrder,
  ...kDowLabels,
  ...kMonthLabels,
  ...kPressureBuckets,
  ...kDaylightBuckets,
  ...kSleepBuckets,
  ...kStressBuckets,
  ..._factorNames,
];

const List<String> _factorNames = [
  'Day of week',
  'Season',
  'Month',
  'Moon phase',
  'Daylight hours',
  'Pressure Δ 24h (hPa)',
  kSleepFactor,
  kStressFactor,
  kTriggerFactor,
  kFoodFactor,
];

final Map<String, String Function(AppLocalizations)> _labels = {
  // Default triggers.
  'Stress': (l) => l.dataTriggerStress,
  'Sleep change': (l) => l.dataTriggerSleepChange,
  'Bright light': (l) => l.dataTriggerBrightLight,
  'Exercise': (l) => l.dataTriggerExercise,
  'Weather / pressure': (l) => l.dataTriggerWeather,
  'Alcohol': (l) => l.dataTriggerAlcohol,
  'Caffeine': (l) => l.dataTriggerCaffeine,
  'Food': (l) => l.dataTriggerFood,
  'Hormonal': (l) => l.dataTriggerHormonal,
  'Strong smell': (l) => l.dataTriggerStrongSmell,
  'Screen time': (l) => l.dataTriggerScreenTime,
  'Travel': (l) => l.dataTriggerTravel,
  // Default head locations.
  'Left temple': (l) => l.dataHeadLeftTemple,
  'Right temple': (l) => l.dataHeadRightTemple,
  'Behind left eye': (l) => l.dataHeadBehindLeftEye,
  'Behind right eye': (l) => l.dataHeadBehindRightEye,
  'Forehead': (l) => l.dataHeadForehead,
  'Top of head': (l) => l.dataHeadTop,
  'Back of head': (l) => l.dataHeadBack,
  'Neck': (l) => l.dataHeadNeck,
  'Both sides': (l) => l.dataHeadBothSides,
  // Default symptoms.
  'Nausea': (l) => l.dataSymptomNausea,
  'Vomiting': (l) => l.dataSymptomVomiting,
  'Light sensitivity': (l) => l.dataSymptomLight,
  'Sound sensitivity': (l) => l.dataSymptomSound,
  'Smell sensitivity': (l) => l.dataSymptomSmell,
  'Neck pain / stiffness': (l) => l.dataSymptomNeck,
  'Dizziness': (l) => l.dataSymptomDizziness,
  'Vertigo': (l) => l.dataSymptomVertigo,
  'Motion sensitivity': (l) => l.dataSymptomMotion,
  'Fatigue': (l) => l.dataSymptomFatigue,
  'Brain fog': (l) => l.dataSymptomBrainFog,
  'Yawning': (l) => l.dataSymptomYawning,
  // Default relief ("Caffeine" is shared with the triggers).
  'Dark room': (l) => l.dataReliefDarkRoom,
  'Sleep': (l) => l.dataReliefSleep,
  'Cold pack': (l) => l.dataReliefColdPack,
  'Heat': (l) => l.dataReliefHeat,
  'Hydration': (l) => l.dataReliefHydration,
  'Rest': (l) => l.dataReliefRest,
  // Seasons.
  'Winter': (l) => l.dataSeasonWinter,
  'Spring': (l) => l.dataSeasonSpring,
  'Summer': (l) => l.dataSeasonSummer,
  'Autumn': (l) => l.dataSeasonAutumn,
  // Moon phases.
  'New Moon': (l) => l.dataMoonNew,
  'Waxing Crescent': (l) => l.dataMoonWaxingCrescent,
  'First Quarter': (l) => l.dataMoonFirstQuarter,
  'Waxing Gibbous': (l) => l.dataMoonWaxingGibbous,
  'Full Moon': (l) => l.dataMoonFull,
  'Waning Gibbous': (l) => l.dataMoonWaningGibbous,
  'Last Quarter': (l) => l.dataMoonLastQuarter,
  'Waning Crescent': (l) => l.dataMoonWaningCrescent,
  // Time of day.
  'morning': (l) => l.dataTimeMorning,
  'afternoon': (l) => l.dataTimeAfternoon,
  'evening': (l) => l.dataTimeEvening,
  'night': (l) => l.dataTimeNight,
  // Factor names (Suspected Factors and Migraine days vs clear days; "Stress" is shared with the
  // triggers).
  'Day of week': (l) => l.dataFactorDayOfWeek,
  'Season': (l) => l.dataFactorSeason,
  'Month': (l) => l.dataFactorMonth,
  'Moon phase': (l) => l.dataFactorMoonPhase,
  'Daylight hours': (l) => l.dataFactorDaylight,
  'Pressure Δ 24h (hPa)': (l) => l.dataFactorPressure,
  kSleepFactor: (l) => l.dataFactorSleep,
  kTriggerFactor: (l) => l.dataFactorTrigger,
  kFoodFactor: (l) => l.dataFactorFood,
};

/// The numeric buckets: same bounds in every language, with the locale's decimal separator and
/// wording.
String? _bucketLabel(AppLocalizations l, String value) {
  String n(num v) => NumberFormat.decimalPattern(formatLocale(l)).format(v);
  String h(num v) => l.dataHours(n(v));
  return switch (value) {
    // Pressure Δ 24h, hPa.
    '< -10' => l.dataBucketBelow(n(-10)),
    '-10 to -5' => l.dataBucketRange(n(-10), n(-5)),
    '-5 to 0' => l.dataBucketRange(n(-5), n(0)),
    '0 to 5' => l.dataBucketRange(n(0), n(5)),
    '5 to 10' => l.dataBucketRange(n(5), n(10)),
    '> 10' => l.dataBucketAbove(n(10)),
    // Daylight hours.
    '< 9.5 h' => l.dataBucketBelow(h(9.5)),
    '9.5–11 h' => l.dataHours(l.dataBucketSpan(n(9.5), n(11))),
    '11–12.5 h' => l.dataHours(l.dataBucketSpan(n(11), n(12.5))),
    '12.5–14 h' => l.dataHours(l.dataBucketSpan(n(12.5), n(14))),
    '≥ 14 h' => l.dataBucketAtLeast(h(14)),
    // Sleep the night before.
    '< 6 h' => l.dataBucketBelow(h(6)),
    '6–8 h' => l.dataHours(l.dataBucketSpan(n(6), n(8))),
    '> 8 h' => l.dataBucketAbove(h(8)),
    // Stress level.
    '1–2' => l.dataBucketSpan(n(1), n(2)),
    '3' => n(3),
    '4–5' => l.dataBucketSpan(n(4), n(5)),
    _ => null,
  };
}
