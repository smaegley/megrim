import 'dart:math' as math;

/// Great-circle distance between two points, for the "away from home" statistic (backlog #13).
///
/// Haversine on a spherical Earth. Megrim stores coordinates rounded to 2 decimals (~1 km, SPEC
/// §3.1), and the only consumer compares against a 100 km threshold, so the ~0.5% error of a
/// spherical model versus a proper geodesic is irrelevant here — and it keeps the function pure,
/// dependency-free and trivially testable.
const double _deg2rad = math.pi / 180.0;

/// Mean Earth radius (km), the usual haversine constant.
const double kEarthRadiusKm = 6371.0088;

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = (lat2 - lat1) * _deg2rad;
  // Longitude difference is taken on the raw values: cos() and the sin²(Δ/2) term are periodic, so
  // a pair straddling the antimeridian (e.g. +179.9 and -179.9) comes out as the short way round
  // without any explicit wrapping.
  final dLon = (lon2 - lon1) * _deg2rad;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * _deg2rad) *
          math.cos(lat2 * _deg2rad) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  // clamp guards against a >1 from floating-point error at antipodal-ish inputs (asin/atan2 of a
  // value a hair over 1 is NaN).
  return 2 * kEarthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
}
