import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo geocoding search (same host family as the weather API — no extra network host).
class GeoResult {
  final String label;
  final double lat;
  final double lon;
  const GeoResult({required this.label, required this.lat, required this.lon});
}

class Geocoder {
  final http.Client _http;
  Geocoder({http.Client? httpClient}) : _http = httpClient ?? http.Client();
  void close() => _http.close();

  Future<List<GeoResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '8',
      'language': 'en',
      'format': 'json',
    });
    final resp = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return const [];
    final results = (jsonDecode(resp.body) as Map)['results'];
    if (results is! List) return const [];
    return results.map((r) {
      final m = r as Map;
      final parts = [
        m['name'],
        m['admin1'],
        m['country'],
      ].where((e) => e != null && '$e'.isNotEmpty).join(', ');
      return GeoResult(
        label: parts,
        lat: (m['latitude'] as num).toDouble(),
        lon: (m['longitude'] as num).toDouble(),
      );
    }).toList();
  }
}
