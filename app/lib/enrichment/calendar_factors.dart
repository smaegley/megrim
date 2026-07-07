/// Trivial local calendar factors (SPEC §5.3): day-of-week, meteorological season
/// (hemisphere-aware), and time-of-day bucket. No network.

/// Season names, matching the private app's analytics vocabulary.
const List<String> kSeasons = ['Winter', 'Spring', 'Summer', 'Autumn'];

/// Time-of-day bucket names.
const List<String> kTimeOfDayBuckets = ['morning', 'afternoon', 'evening', 'night'];

class CalendarFactors {
  /// 0 = Mon .. 6 = Sun.
  final int dayOfWeek;
  final String season;
  final String timeOfDayBucket;

  const CalendarFactors({
    required this.dayOfWeek,
    required this.season,
    required this.timeOfDayBucket,
  });
}

/// 0 = Mon .. 6 = Sun for [local] (Dart weekday is 1=Mon..7=Sun).
int dayOfWeekMon0(DateTime local) => local.weekday - 1;

/// Meteorological season for [month] (1–12) at [lat]; southern hemisphere is flipped.
String seasonForMonth(int month, double lat) {
  // Northern meteorological seasons.
  final String north;
  if (month == 12 || month == 1 || month == 2) {
    north = 'Winter';
  } else if (month >= 3 && month <= 5) {
    north = 'Spring';
  } else if (month >= 6 && month <= 8) {
    north = 'Summer';
  } else {
    north = 'Autumn';
  }
  if (lat >= 0) return north;
  // Southern hemisphere: opposite season.
  switch (north) {
    case 'Winter':
      return 'Summer';
    case 'Summer':
      return 'Winter';
    case 'Spring':
      return 'Autumn';
    default:
      return 'Spring';
  }
}

/// morning 05–11 / afternoon 12–16 / evening 17–20 / night 21–04 (local hour).
String timeOfDayBucket(int localHour) {
  if (localHour >= 5 && localHour <= 11) return 'morning';
  if (localHour >= 12 && localHour <= 16) return 'afternoon';
  if (localHour >= 17 && localHour <= 20) return 'evening';
  return 'night';
}

/// Compute all calendar factors for an event.
///
/// [local] is the event's start time in the user's local timezone (typically
/// `startedAt.toLocal()`); day-of-week, season, and time-of-day are all local-calendar concepts.
/// [lat] selects the hemisphere for the season.
CalendarFactors computeCalendarFactors(DateTime local, double lat) {
  return CalendarFactors(
    dayOfWeek: dayOfWeekMon0(local),
    season: seasonForMonth(local.month, lat),
    timeOfDayBucket: timeOfDayBucket(local.hour),
  );
}
