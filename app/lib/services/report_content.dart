/// Everything that appears on the printable report (backlog #12), already formatted into strings.
///
/// Pure: no PDF, no fonts, no I/O, no clock of its own. `report_pdf.dart` only draws what this
/// decides, so the wording, ordering and gating are all testable without rendering anything.
///
/// Built from [DashboardResult] and [CorrelationResult] — the same objects behind the Analytics
/// tab and the `analytics` export block — so the report, the tab and the export can never disagree
/// about a number.
library;

import 'package:intl/intl.dart';

import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../database/database.dart';
import '../legal.dart' show kMedicalDisclaimer, kWeatherAttribution;
import '../models/event_time.dart';
import '../models/json_fields.dart';


class ReportStat {
  final String label;
  final String value;
  const ReportStat(this.label, this.value);
}

class ReportBar {
  final String label;
  final int count;
  const ReportBar(this.label, this.count);
}

class ReportChart {
  final String title;
  final String? note;
  final List<ReportBar> bars;
  const ReportChart({required this.title, this.note, required this.bars});
}

class ReportMedRow {
  final String name;
  final int taken;
  final int helped;
  final int notHelped;
  final int unknown;

  /// Share of *recorded* outcomes where it helped; null when every outcome is unknown.
  final int? helpedPct;
  const ReportMedRow({
    required this.name,
    required this.taken,
    required this.helped,
    required this.notHelped,
    required this.unknown,
    required this.helpedPct,
  });
}

class ReportFactorRow {
  final String bucket;
  final int migraineDays;
  final int totalDays;
  final double ratePct;
  final double oddsRatio;

  /// True for rows the app itself lists as a headline factor, marked on the page.
  final bool isTop;
  const ReportFactorRow({
    required this.bucket,
    required this.migraineDays,
    required this.totalDays,
    required this.ratePct,
    required this.oddsRatio,
    this.isTop = false,
  });
}

class ReportFactorGroup {
  final String name;
  final List<ReportFactorRow> rows;
  const ReportFactorGroup({required this.name, required this.rows});
}

class ReportEventRow {
  final String date;
  final String time;
  final String severity;
  final String duration;
  final String aura;
  final String headLocations;
  final String triggers;
  final String meds;
  final String notes;
  const ReportEventRow({
    required this.date,
    required this.time,
    required this.severity,
    required this.duration,
    required this.aura,
    required this.headLocations,
    required this.triggers,
    required this.meds,
    required this.notes,
  });
}

class ReportContent {
  final String title;
  final String subtitle;
  final List<ReportStat> summary;
  final List<ReportChart> charts;

  /// One line from the away-from-home share (backlog #13); null when it isn't available.
  final String? awayFromHome;

  final List<ReportBar> triggerFrequency;
  final List<ReportMedRow> medications;

  /// False when there are too few events; [factorsReason] then says why.
  final bool factorsAvailable;
  final String? factorsReason;
  final String factorsWindow;
  final List<ReportFactorGroup> factorGroups;
  final List<String> caveats;

  final List<ReportEventRow> events;

  /// Things the reader needs to know that aren't wrong, just absent — a missing pressure baseline,
  /// characters the embedded font can't draw.
  final List<String> footnotes;
  final String methods;
  final String disclaimer;

  const ReportContent({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.charts,
    required this.awayFromHome,
    required this.triggerFrequency,
    required this.medications,
    required this.factorsAvailable,
    required this.factorsReason,
    required this.factorsWindow,
    required this.factorGroups,
    required this.caveats,
    required this.events,
    required this.footnotes,
    required this.methods,
    required this.disclaimer,
  });
}

const String kReportMethods =
    'Descriptive charts are plain counts of logged entries: a tall bar means more migraines were '
    'logged there, nothing more. Suspected factors use the unit of a migraine-day, and every day '
    'between the first and last migraine is a baseline day. For each bucket a 2x2 table is built '
    'and a Haldane-Anscombe corrected odds ratio computed (0.5 added to every cell). A factor is '
    'marked as a headline row only if its bucket covers at least 3 migraine-days and its odds '
    'ratio exceeds 1. Moon phase and daylight are computed astronomically from the home location; '
    'season is hemisphere-corrected.';

/// Readable stand-ins for symbols the report font lacks. Noto Sans (Latin/Greek/Cyrillic) has no
/// U+2265, which the app's own daylight bucket "≥ 14 h" uses — ">= 14 h" reads fine, where the
/// "?" fallback below would not. These are faithful, so they do NOT count as a lost character.
const Map<int, String> kFontTransliterations = {
  0x2265: '>=', // ≥
  0x2264: '<=', // ≤
  0x2260: '!=', // ≠
  0x2212: '-', // − (minus sign, not hyphen)
  0x00D7: 'x', // ×
};

/// Replaces runes the embedded font cannot draw. Without this they render as nothing at all —
/// the PDF library maps an unknown rune to glyph 0 with zero width — so a note written in, say,
/// Japanese would silently vanish from the report instead of being visibly incomplete.
///
/// `substituted` reports only genuine losses (the "?" fallback), not the readable
/// [kFontTransliterations].
({String text, bool substituted}) sanitiseForFont(
    String input, bool Function(int rune) canRender) {
  var substituted = false;
  final out = StringBuffer();
  for (final rune in input.runes) {
    // Keep newlines and tabs; they're laid out, not drawn.
    if (rune == 0x0A || rune == 0x09 || canRender(rune)) {
      out.writeCharCode(rune);
      continue;
    }
    final swap = kFontTransliterations[rune];
    if (swap != null) {
      out.write(swap);
      continue;
    }
    substituted = true;
    out.write('?');
  }
  return (text: out.toString(), substituted: substituted);
}

String _fmtDuration(Duration d) {
  final h = d.inMinutes / 60.0;
  if (h < 1) return '${d.inMinutes}m';
  if (h < 24) return '${(h * 10).round() / 10}h';
  return '${d.inDays}d ${(d.inHours % 24)}h';
}

ReportContent buildReportContent({
  required DashboardResult dash,
  required CorrelationResult corr,
  required List<MigraineEvent> events,
  required String appVersion,
  required DateTime now,
  String? homeLabel,
  bool weatherEnabled = true,
  bool Function(int rune)? canRender,
}) {
  var anySubstituted = false;
  String clean(String? s) {
    if (s == null || s.isEmpty) return '';
    if (canRender == null) return s;
    final r = sanitiseForFont(s, canRender);
    if (r.substituted) anySubstituted = true;
    return r.text;
  }

  final df = DateFormat('d MMM yyyy');
  final s = dash.summary;

  final subtitleParts = <String>[
    '${s.totalEvents} ${s.totalEvents == 1 ? 'entry' : 'entries'}',
    if (homeLabel != null && homeLabel.isNotEmpty) clean(homeLabel),
    if (s.firstEvent != null && s.lastEvent != null)
      '${df.format(s.firstEvent!)} to ${df.format(s.lastEvent!)}',
    'generated ${df.format(now)}',
    'Megrim $appVersion',
  ];

  final summary = <ReportStat>[
    ReportStat('Entries', '${s.totalEvents}'),
    ReportStat('Years tracked', '${s.yearsTracked}'),
    ReportStat('Avg severity', s.avgSeverity != null ? '${s.avgSeverity}/10' : '-'),
    ReportStat('Avg duration',
        s.avgDurationHours != null ? '${s.avgDurationHours}h' : '-'),
    ReportStat(
        'Avg interval', s.avgIntervalDays != null ? '${s.avgIntervalDays}d' : '-'),
    ReportStat('Per year', '${s.eventsPerYear}'),
  ];

  List<ReportBar> bars(List<LabeledCount> l) =>
      [for (final c in l) ReportBar(clean(c.label), c.count)];

  final charts = <ReportChart>[
    if (dash.byYear.isNotEmpty)
      ReportChart(
        title: 'By year',
        bars: [for (final y in dash.byYear) ReportBar('${y.year}', y.count)],
      ),
    ReportChart(title: 'By day of week', bars: bars(dash.byDayOfWeek)),
    ReportChart(title: 'By season', bars: bars(dash.bySeason)),
    ReportChart(title: 'By time of day', bars: bars(dash.byTimeOfDay)),
    ReportChart(title: 'By daylight hours', bars: bars(dash.byDaylight)),
    ReportChart(
      title: 'Pressure change (24h)',
      note: weatherEnabled ? null : 'Weather enrichment is off, so this is empty.',
      bars: bars(dash.pressureDelta),
    ),
    ReportChart(title: 'By moon phase', bars: bars(dash.byMoonPhase)),
  ];

  String? away;
  final a = dash.awayFromHome;
  if (a != null) {
    final km = a.thresholdKm.round();
    if (a.awayEvents == 0) {
      away = 'All ${a.locatedEvents} located '
          '${a.locatedEvents == 1 ? 'entry was' : 'entries were'} within $km km of home.';
    } else {
      away = '${a.awayEvents} of ${a.locatedEvents} located entries (${a.awayPct}%) '
          'were recorded more than $km km from home'
          '${a.awayPlaces.isEmpty ? '' : ': ${a.awayPlaces.take(5).map((p) => '${clean(p.label)} (${p.count})').join(', ')}'}.';
    }
  }

  // Medications, tallied across every event (the dashboard doesn't carry these).
  final medTally = <String, List<int>>{}; // name -> [taken, helped, notHelped, unknown]
  for (final e in events) {
    for (final m in decodeMeds(e.medsTaken)) {
      if (m.name.isEmpty) continue;
      final row = medTally.putIfAbsent(m.name, () => [0, 0, 0, 0]);
      row[0]++;
      if (m.helped == true) {
        row[1]++;
      } else if (m.helped == false) {
        row[2]++;
      } else {
        row[3]++;
      }
    }
  }
  final medications = medTally.entries.map((e) {
    final recorded = e.value[1] + e.value[2];
    return ReportMedRow(
      name: clean(e.key),
      taken: e.value[0],
      helped: e.value[1],
      notHelped: e.value[2],
      unknown: e.value[3],
      helpedPct: recorded == 0 ? null : (100 * e.value[1] / recorded).round(),
    );
  }).toList()
    ..sort((x, y) => y.taken.compareTo(x.taken));

  // Factors: every bucket row, with the app's own headline rows marked rather than repeated in a
  // second table. Matches what tools/report.html settled on after review.
  final topKeys = {
    for (final t in corr.topFactors) '${t.factor}|${t.condition}',
  };
  final factorGroups = <ReportFactorGroup>[
    for (final entry in corr.factors.entries)
      if (entry.value.isNotEmpty)
        ReportFactorGroup(
          name: clean(entry.key),
          rows: [
            for (final r in entry.value)
              ReportFactorRow(
                bucket: clean(r.bucket),
                migraineDays: r.migraineDays,
                totalDays: r.totalDays,
                ratePct: r.migraineRatePct,
                oddsRatio: r.oddsRatio,
                isTop: topKeys.contains('${entry.key}|${r.bucket}'),
              ),
          ],
        ),
  ];

  final sorted = [...events]..sort((x, y) => y.startedAt.compareTo(x.startedAt));
  final dfRow = DateFormat('d MMM yyyy');
  final tf = DateFormat('HH:mm');
  final eventRows = <ReportEventRow>[
    for (final e in sorted)
      ReportEventRow(
        date: dfRow.format(e.startedWall),
        time: tf.format(e.startedWall),
        severity: e.severity?.toString() ?? '-',
        duration: e.endedAt == null
            ? 'ongoing'
            : (e.endedAt!.isBefore(e.startedAt)
                ? '-'
                : _fmtDuration(e.endedAt!.difference(e.startedAt))),
        aura: e.auraPresent == null ? '-' : (e.auraPresent! ? 'yes' : 'no'),
        headLocations: clean(decodeStringList(e.locationHead).join(', ')),
        triggers: clean(decodeStringList(e.triggersSuspected).join(', ')),
        meds: clean(decodeMeds(e.medsTaken)
            .map((m) => [m.name, if (m.dose != null && m.dose!.isNotEmpty) m.dose!].join(' '))
            .join(', ')),
        notes: clean(e.notes),
      ),
  ];

  final footnotes = <String>[
    if (!corr.factors.containsKey('Pressure Δ 24h (hPa)'))
      'The barometric-pressure factor is not shown: it needs a cached pressure history for your '
          'home location, which the app builds the first time Analytics runs online with weather '
          'enrichment on. Its absence here means "not available", not "no effect".',
    kWeatherAttribution,
  ];

  // Built last: `clean` sets the flag as it goes, so this has to come after every call to it.
  if (anySubstituted) {
    footnotes.insert(
      0,
      'Some characters in your entries could not be drawn with this report\'s font and appear as '
          '"?". The app itself still holds them correctly, and a JSON export preserves them.',
    );
  }

  return ReportContent(
    title: 'Migraine report',
    subtitle: subtitleParts.join(' · '),
    summary: summary,
    charts: charts,
    awayFromHome: away,
    triggerFrequency: bars(dash.triggerFrequency),
    medications: medications,
    factorsAvailable: corr.available,
    factorsReason: corr.reason,
    factorsWindow: corr.available
        ? '${corr.totalMigraineDays} migraine-days over ${corr.totalDaysInRange} days '
            '(${corr.baseRatePct}% of days).'
        : '',
    factorGroups: factorGroups,
    caveats: corr.caveats,
    events: eventRows,
    footnotes: footnotes,
    methods: kReportMethods,
    disclaimer: kMedicalDisclaimer,
  );
}
