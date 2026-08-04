import 'package:open_location_code/open_location_code.dart';

import '../models/home_location.dart';

/// Offline manual location entry: decimal GPS coordinates ("40.01, -105.27") or a full
/// Plus Code ("849VCWC8+R9" — Open Location Code, decoded by pure local math). Returns null when
/// [raw] is neither. Never touches the network — this is the privacy alternative to the
/// Open-Meteo geocoder search (SPEC §4.1).
HomeLocation? parseManualLocation(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  final gps = RegExp(r'^(-?\d{1,3}(?:\.\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:\.\d+)?)$')
      .firstMatch(input);
  if (gps != null) {
    final lat = double.parse(gps.group(1)!);
    final lon = double.parse(gps.group(2)!);
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return HomeLocation(
      lat: lat,
      lon: lon,
      label: '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
    );
  }

  if (input.contains('+')) {
    final code = PlusCode(input.toUpperCase());
    if (code.isValid && code.isFull()) {
      final center = code.decode().center;
      return HomeLocation(
        lat: center.latitude,
        lon: center.longitude,
        label: input.toUpperCase(),
      );
    }
  }
  return null;
}

/// True when [value] is plausibly a manual entry being typed (leading digit or minus sign, or a
/// '+' anywhere — no place name matches those). Used to suppress the geocoder while typing, so a
/// half-typed coordinate is never sent over the network as a search query.
bool looksLikeManualLocation(String value) {
  final t = value.trim();
  if (t.isEmpty) return false;
  final c = t.codeUnitAt(0);
  return c == 0x2D /* - */ || (c >= 0x30 && c <= 0x39) || t.contains('+');
}
