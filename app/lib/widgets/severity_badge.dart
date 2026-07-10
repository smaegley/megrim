import 'package:flutter/material.dart';

/// Shared red→green status palette (from the data-viz status ramp — good/warning/serious/critical).
/// Reused for the severity badge and the "days since last migraine" card so the whole app reads one
/// colour language. These are fixed status hues, deliberately distinct from the categorical series
/// colours used in the charts.
class StatusColors {
  static const Color good = Color(0xFF0CA30C); // green
  static const Color warning = Color(0xFFFAB219); // yellow
  static const Color serious = Color(0xFFEC835A); // orange
  static const Color critical = Color(0xFFD03B3B); // red
  static const Color neutral = Color(0xFF757575); // grey — unknown / not enough data
}

/// Colour for a 1–10 severity on a green→red scale (higher severity = redder). Null ⇒ grey.
Color severityColor(int? severity) {
  if (severity == null) return StatusColors.neutral;
  if (severity <= 3) return StatusColors.good;
  if (severity <= 5) return StatusColors.warning;
  if (severity <= 7) return StatusColors.serious;
  return StatusColors.critical;
}

/// Readable text/foreground colour to place on top of a status fill. Picks whichever of pure
/// black or pure white has the higher WCAG contrast ratio against [fill], rather than a
/// luminance-threshold heuristic — that used to pick white for some fills (e.g. `StatusColors
/// .serious`, an orange) that don't actually clear the 4.5:1 text-contrast minimum against white
/// (found by an accessibility-guideline test: it measured 2.64:1). Choosing the higher-contrast
/// of the two extremes is provably always >= ~4.58:1 for any background, comfortably above 4.5:1.
Color onStatusColor(Color fill) {
  double contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  final blackContrast = contrastRatio(Colors.black, fill);
  final whiteContrast = contrastRatio(Colors.white, fill);
  return blackContrast >= whiteContrast ? Colors.black : Colors.white;
}

/// A small coloured circle showing a migraine's severity number, scaled green→red.
/// Shown at the leading edge of each History row (SPEC review item #2).
class SeverityBadge extends StatelessWidget {
  final int? severity;
  final double size;
  const SeverityBadge({super.key, required this.severity, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        severity?.toString() ?? '–',
        style: TextStyle(
          color: onStatusColor(color),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
