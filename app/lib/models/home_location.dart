import 'dart:convert';

/// The user's home location, set in onboarding and used as the enrichment fallback
/// when GPS is unavailable/denied. Stored in app_settings under `home_location`.
class HomeLocation {
  final double lat;
  final double lon;
  final String label;

  const HomeLocation({
    required this.lat,
    required this.lon,
    required this.label,
  });

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'label': label};

  factory HomeLocation.fromJson(Map<String, dynamic> j) => HomeLocation(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        label: j['label'] as String? ?? '',
      );

  String encode() => jsonEncode(toJson());

  static HomeLocation? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return HomeLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
