import 'dart:math' as math;

/// On-device astronomical calculations (SPEC §5.2). Pure math, no network, no dependencies.
///
/// - Sunrise/sunset/daylight via the NOAA solar equations (accuracy ±1–2 min).
/// - Moon phase & illumination from the mean synodic cycle since a known new-moon epoch.
///
/// The moon-phase algorithm here is the single source of truth: the analytics correlations
/// baseline (§6.2) computes moon phase for arbitrary dates using [moonPhaseName] so the enriched
/// values and the baseline agree.

/// The eight named lunar phases, in cycle order.
const List<String> kMoonPhases = [
  'New Moon',
  'Waxing Crescent',
  'First Quarter',
  'Waxing Gibbous',
  'Full Moon',
  'Waning Gibbous',
  'Last Quarter',
  'Waning Crescent',
];

/// Reference new moon: 2000-01-06 18:14 UTC. Synodic month length in days.
const double _synodicMonth = 29.530588853;
final DateTime _newMoonEpoch = DateTime.utc(2000, 1, 6, 18, 14);

const double _deg2rad = math.pi / 180.0;
const double _rad2deg = 180.0 / math.pi;

class AstroResult {
  final DateTime? sunriseUtc;
  final DateTime? sunsetUtc;

  /// Hours of daylight (0 during polar night, 24 during polar day).
  final double daylightHours;

  final String moonPhase;

  /// Illuminated fraction of the moon's disc, 0 (new) .. 1 (full).
  final double moonIllumination;

  const AstroResult({
    required this.sunriseUtc,
    required this.sunsetUtc,
    required this.daylightHours,
    required this.moonPhase,
    required this.moonIllumination,
  });
}

/// Fraction (0..1) through the synodic cycle for [instant]: 0 = new, 0.5 = full.
double moonPhaseFraction(DateTime instant) {
  final days = instant.toUtc().difference(_newMoonEpoch).inMicroseconds /
      Duration.microsecondsPerDay;
  var frac = (days % _synodicMonth) / _synodicMonth;
  if (frac < 0) frac += 1.0;
  return frac;
}

/// Illuminated fraction for [instant].
double moonIllumination(DateTime instant) {
  final frac = moonPhaseFraction(instant);
  return (1 - math.cos(2 * math.pi * frac)) / 2;
}

/// Named phase for [instant], using the same bucket boundaries as the private app's Python
/// implementation so enrichment and the correlations baseline stay consistent.
String moonPhaseName(DateTime instant) {
  final frac = moonPhaseFraction(instant);
  if (frac < 0.0625 || frac >= 0.9375) return 'New Moon';
  if (frac < 0.1875) return 'Waxing Crescent';
  if (frac < 0.3125) return 'First Quarter';
  if (frac < 0.4375) return 'Waxing Gibbous';
  if (frac < 0.5625) return 'Full Moon';
  if (frac < 0.6875) return 'Waning Gibbous';
  if (frac < 0.8125) return 'Last Quarter';
  return 'Waning Crescent';
}

/// Sunrise/sunset (UTC) and daylight hours for the calendar date of [instant] at ([lat], [lon]).
///
/// [lon] is degrees east (negative for west). Uses the NOAA algorithm with the standard
/// 90.833° zenith (refraction + solar disc). Returns null sunrise/sunset for polar day/night.
({DateTime? sunrise, DateTime? sunset, double daylightHours}) sunTimes(
  DateTime instant,
  double lat,
  double lon,
) {
  // Local calendar date, approximated from longitude (15° per hour). Sunrise/sunset move slowly
  // day-to-day, so this only matters right at a date boundary.
  final localApprox = instant.toUtc().add(
        Duration(minutes: (lon / 15.0 * 60).round()),
      );
  final date = DateTime.utc(localApprox.year, localApprox.month, localApprox.day);
  final dayOfYear = date.difference(DateTime.utc(date.year, 1, 1)).inDays + 1;

  // Fractional year (radians), evaluated near local noon.
  final gamma = (2 * math.pi / _daysInYear(date.year)) * (dayOfYear - 1 + 0.5);

  final eqTime = 229.18 *
      (0.000075 +
          0.001868 * math.cos(gamma) -
          0.032077 * math.sin(gamma) -
          0.014615 * math.cos(2 * gamma) -
          0.040849 * math.sin(2 * gamma));

  final decl = 0.006918 -
      0.399912 * math.cos(gamma) +
      0.070257 * math.sin(gamma) -
      0.006758 * math.cos(2 * gamma) +
      0.000907 * math.sin(2 * gamma) -
      0.002697 * math.cos(3 * gamma) +
      0.00148 * math.sin(3 * gamma);

  final latRad = lat * _deg2rad;
  final zenith = 90.833 * _deg2rad;
  final cosHa = (math.cos(zenith) / (math.cos(latRad) * math.cos(decl))) -
      math.tan(latRad) * math.tan(decl);

  if (cosHa > 1.0) {
    // Sun never rises above the horizon: polar night.
    return (sunrise: null, sunset: null, daylightHours: 0.0);
  }
  if (cosHa < -1.0) {
    // Sun never sets: polar day.
    return (sunrise: null, sunset: null, daylightHours: 24.0);
  }

  final haDeg = math.acos(cosHa) * _rad2deg;

  // Minutes from UTC midnight.
  final sunriseMin = 720 - 4 * (lon + haDeg) - eqTime;
  final sunsetMin = 720 - 4 * (lon - haDeg) - eqTime;

  final sunrise = _minutesToUtc(date, sunriseMin);
  final sunset = _minutesToUtc(date, sunsetMin);
  final daylight = (sunsetMin - sunriseMin) / 60.0;

  return (sunrise: sunrise, sunset: sunset, daylightHours: daylight);
}

/// Full astronomical enrichment for an event at ([lat], [lon]) occurring at [instant] (UTC).
AstroResult computeAstro(DateTime instant, double lat, double lon) {
  final sun = sunTimes(instant, lat, lon);
  return AstroResult(
    sunriseUtc: sun.sunrise,
    sunsetUtc: sun.sunset,
    daylightHours: sun.daylightHours,
    moonPhase: moonPhaseName(instant),
    moonIllumination: moonIllumination(instant),
  );
}

int _daysInYear(int year) =>
    (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 366 : 365;

DateTime _minutesToUtc(DateTime dateUtcMidnight, double minutes) {
  // minutes may fall outside [0,1440) near date boundaries / high longitudes; DateTime handles
  // the carry into adjacent days.
  final micros = (minutes * Duration.microsecondsPerMinute).round();
  return dateUtcMidnight.add(Duration(microseconds: micros));
}
