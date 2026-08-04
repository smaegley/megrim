import 'dart:async';

import 'package:flutter/material.dart';

import '../models/home_location.dart';
import '../services/geocoder.dart';
import '../services/location_input.dart';

/// Search-as-you-type location picker backed by the Open-Meteo geocoder, with a fully-offline
/// alternative: typing decimal GPS coordinates or a full Plus Code is recognised locally and
/// offered as an instant result — no search request is sent (input that even *looks* like a
/// manual entry suppresses the geocoder, so half-typed coordinates never leak as queries).
/// Coordinates are rounded to 2 decimals when a result is chosen (privacy — SPEC §5.1).
class LocationPickerField extends StatefulWidget {
  final ValueChanged<HomeLocation> onSelected;
  final HomeLocation? initial;

  /// Injectable for tests (same pattern as the app's other network services); defaults to a real
  /// [Geocoder] when omitted.
  final Geocoder? geocoder;
  const LocationPickerField(
      {super.key, required this.onSelected, this.initial, this.geocoder});

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  final _controller = TextEditingController();
  late final Geocoder _geocoder = widget.geocoder ?? Geocoder();
  Timer? _debounce;
  List<GeoResult> _results = const [];
  bool _loading = false;
  HomeLocation? _chosen;

  /// Parsed offline entry (GPS pair / Plus Code) for the current input, if it is one.
  HomeLocation? _manual;

  @override
  void initState() {
    super.initState();
    _chosen = widget.initial;
    if (widget.initial != null) _controller.text = widget.initial!.label;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _geocoder.close();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (looksLikeManualLocation(value)) {
      // Manual entry in progress: never query the geocoder, offer the parsed result (if it
      // parses yet) as an offline choice instead.
      setState(() {
        _manual = parseManualLocation(value);
        _results = const [];
        _loading = false;
      });
      return;
    }
    if (_manual != null) setState(() => _manual = null);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    if (value.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _geocoder.search(value);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectManual() {
    final m = _manual;
    if (m == null) return;
    final loc = HomeLocation(
      lat: (m.lat * 100).roundToDouble() / 100,
      lon: (m.lon * 100).roundToDouble() / 100,
      label: m.label,
    );
    setState(() {
      _chosen = loc;
      _controller.text = m.label;
      _manual = null;
    });
    widget.onSelected(loc);
  }

  void _select(GeoResult r) {
    final loc = HomeLocation(
      lat: (r.lat * 100).roundToDouble() / 100,
      lon: (r.lon * 100).roundToDouble() / 100,
      label: r.label,
    );
    setState(() {
      _chosen = loc;
      _controller.text = r.label;
      _results = const [];
    });
    widget.onSelected(loc);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: 'City search — or GPS / Plus Code',
            helperText: 'e.g. Boulder · 40.01, -105.27 · 849VCWC8+R9',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_manual != null)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.pin_drop_outlined),
              title: Text('Use ${_manual!.label}'),
              subtitle: const Text('Entered directly — nothing sent online'),
              onTap: _selectManual,
            ),
          ),
        if (_results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            child: Column(
              children: [
                for (final r in _results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.label),
                    onTap: () => _select(r),
                  ),
              ],
            ),
          ),
        if (_chosen != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selected: ${_chosen!.label} '
              '(${_chosen!.lat.toStringAsFixed(2)}, ${_chosen!.lon.toStringAsFixed(2)})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
