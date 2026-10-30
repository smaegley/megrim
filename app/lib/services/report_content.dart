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
import '../analytics/medications.dart';
import '../database/database.dart';
import '../legal.dart' show kMedicalDisclaimer, kWeatherAttribution;
import '../models/attack_details.dart';
import '../models/event_time.dart';
import '../models/json_fields.dart';
import '../models/medications.dart';


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

/// "Acute medication days" (backlog #18). Null on [ReportContent] until an entry has a
/// medication, and the section is left out.
class ReportMedicationDays {
  /// The last 30 days, in all and per class.
  final String summary;

  /// Month, then "Any", then one column per class seen in those months.
  final List<String> headers;
  final List<List<String>> rows;

  /// The overuse notice as lines (title, one per qualifying month, the explanation); empty when
  /// it isn't raised.
  final List<String> notice;

  /// Says which medications have no class; null when all do.
  final String? unclassified;

  const ReportMedicationDays({
    required this.summary,
    required this.headers,
    required this.rows,
    this.notice = const [],
    this.unclassified,
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

/// Backlog #16: the self-reported factors, migraine days vs clear days over tracked days.
class ReportTrackedFactors {
  final bool available;
  final String? reason;
  final String window;
  final List<ReportFactorGroup> groups;
  final List<String> caveats;
  const ReportTrackedFactors({
    required this.available,
    this.reason,
    this.window = '',
    this.groups = const [],
    this.caveats = const [],
  });
}

/// The "Attacks without headache" section (backlog #26). Null on [ReportContent] when there are
/// none, and the section is left out.
class ReportWithoutHeadache {
  /// One sentence: how many, what share, the split by kind, the median length.
  final String summary;
  final List<ReportBar> byKind;
  final List<ReportBar> symptoms;
  const ReportWithoutHeadache({
    required this.summary,
    required this.byKind,
    required this.symptoms,
  });
}

class ReportEventRow {
  final String date;
  final String time;

  /// "none" for an attack without headache (backlog #26), "-" when not recorded.
  final String severity;
  final String duration;
  final String aura;
  final String headLocations;
  final String symptoms;
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
    required this.symptoms,
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

  /// One line of impact-day counts (backlog #22a); null until an entry has an impact recorded.
  final String? impact;

  /// One line of days tracked (backlog #16); null until there is a check-in.
  final String? tracked;

  /// Backlog #16; null until there is a check-in.
  final ReportTrackedFactors? trackedFactors;

  final ReportWithoutHeadache? withoutHeadache;

  final List<ReportBar> triggerFrequency;

  /// Backlog #20.
  final List<ReportBar> symptomFrequency;
  final List<ReportMedRow> medications;

  /// Backlog #19: non-drug relief, in the same shape as [medications].
  final List<ReportMedRow> relief;

  /// Backlog #18.
  final ReportMedicationDays? medicationDays;

  /// Backlog #19: one line per preventive regimen, oldest first.
  final List<String> preventives;

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
    this.impact,
    this.tracked,
    this.trackedFactors,
    this.withoutHeadache,
    required this.triggerFrequency,
    this.symptomFrequency = const [],
    required this.medications,
    this.relief = const [],
    this.medicationDays,
    this.preventives = const [],
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
    // Backlog #17: days, not entries — the figure a clinician asks for first.
    ReportStat('Migraine days, last 30 d', '${dash.migraineDaysLast30}'),
  ];

  List<ReportBar> bars(List<LabeledCount> l) =>
      [for (final c in l) ReportBar(clean(c.label), c.count)];

  // Last 12 months of migraine days (backlog #17), the current month marked as unfinished.
  final recentMonths = dash.migraineDaysByMonth.length > 12
      ? dash.migraineDaysByMonth.sublist(dash.migraineDaysByMonth.length - 12)
      : dash.migraineDaysByMonth;
  final thisMonth = DateTime(now.year, now.month);
  final monthLabel = DateFormat('MMM yyyy');
  final recentWithout = recentMonths.fold<int>(0, (n, m) => n + m.daysWithoutHeadache);

  final charts = <ReportChart>[
    if (recentMonths.isNotEmpty)
      ReportChart(
        title: 'Migraine days per month',
        note: 'Days with a migraine, not entries; a multi-day migraine counts each day. '
            '${dash.avgMigraineDaysLast3Months == null ? '' : 'Average over the last 3 complete months: ${dash.avgMigraineDaysLast3Months}. '}'
            '${recentWithout == 0 ? '' : 'Includes $recentWithout ${recentWithout == 1 ? 'day' : 'days'} with only attacks without headache. '}'
            '* month in progress.',
        bars: [
          for (final m in recentMonths)
            ReportBar(
              '${monthLabel.format(DateTime(m.year, m.month))}'
              '${DateTime(m.year, m.month) == thisMonth ? ' *' : ''}',
              m.days,
            ),
        ],
      ),
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

  // Impact on the day (backlog #22a).
  String? impact;
  final i = dash.impact;
  if (i != null) {
    String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
    impact = 'Impact, last 30 days: ${days(i.unableLast30)} unable to function, '
        '${days(i.reducedLast30)} with reduced function (impact recorded on '
        '${i.recordedLast30} of ${dash.migraineDaysLast30} migraine days).'
        '${i.avgUnableLast3Months == null ? '' : ' Monthly average over the last 3 complete '
            'months: ${i.avgUnableLast3Months} unable, ${i.avgReducedLast3Months} reduced.'}';
  }

  // Attacks without headache (backlog #26).
  ReportWithoutHeadache? withoutHeadache;
  final w = dash.withoutHeadache;
  if (w != null) {
    withoutHeadache = ReportWithoutHeadache(
      summary: '${w.events} of ${w.totalEvents} entries (${w.pct}%) were recorded without '
          'headache: ${w.withAura} with aura, ${w.withVertigo} with vertigo or dizziness, '
          '${w.other} other.'
          '${w.medianDurationHours == null ? '' : ' Median length ${w.medianDurationHours}h.'}',
      byKind: [
        ReportBar('With aura', w.withAura),
        ReportBar('With vertigo or dizziness', w.withVertigo),
        ReportBar('Other', w.other),
      ],
      symptoms: bars(w.symptoms),
    );
  }

  // Medications and relief (backlog #19), from the dashboard so the report and the Analytics tab
  // count them the same way.
  ReportMedRow medRow(HelpedRow r) => ReportMedRow(
        name: clean(r.name),
        taken: r.tried,
        helped: r.helped,
        notHelped: r.notHelped,
        unknown: r.unknown,
        helpedPct: r.helpedPct,
      );
  final medications = [for (final r in dash.whatHelped) if (!r.relief) medRow(r)];
  final relief = [for (final r in dash.whatHelped) if (r.relief) medRow(r)];

  // Acute-medication days (backlog #18): the last 12 months as a table, one column per class.
  ReportMedicationDays? medicationDays;
  final md = dash.medicationDays;
  if (md != null) {
    String days(int n) => '$n ${n == 1 ? 'day' : 'days'}';
    final months = md.byMonth.length > 12 ? md.byMonth.sublist(md.byMonth.length - 12) : md.byMonth;
    final classes = [
      for (final c in [...kMedClassLabels.keys, kUnclassified])
        if (months.any((m) => m.byClass.containsKey(c))) c,
    ];
    final breakdown = md.byClassLast30.entries.map((e) => '${medClassName(e.key)} ${e.value}');
    final f = DateFormat('MMM yyyy');
    medicationDays = ReportMedicationDays(
      summary: 'Days with acute medication, last 30 days: ${days(md.last30)}'
          '${breakdown.isEmpty ? '.' : ' (${breakdown.join(', ')}).'}',
      headers: ['Month', 'Any', for (final c in classes) medClassName(c)],
      rows: [
        for (final m in months)
          [
            '${f.format(DateTime(m.year, m.month))}'
                '${DateTime(m.year, m.month) == DateTime(now.year, now.month) ? ' *' : ''}',
            '${m.days}',
            for (final c in classes) '${m.byClass[c] ?? 0}',
          ],
      ],
      notice: md.notice == null
          ? const []
          : [
              kOveruseNoticeTitle,
              for (final m in md.notice!)
                for (final r in m.levelsReached)
                  '${f.format(DateTime(m.year, m.month))}: ${levelReason(m, r)}',
              kOveruseNoticeBody,
            ],
      unclassified: md.unclassifiedNames.isEmpty
          ? null
          : 'No class set for ${md.unclassifiedNames.map(clean).join(', ')}: counted in "Any" '
              'but not checked against the reference levels.',
    );
  }

  final dfDay = DateFormat('d MMM yyyy');
  String day(String iso) {
    final d = parseIsoDay(iso);
    return d == null ? iso : dfDay.format(d);
  }

  final preventives = [
    for (final p in dash.preventives)
      '${clean(p.name)}${p.dose == null ? '' : ' ${clean(p.dose)}'}: '
          '${p.stoppedOn == null ? 'since ${day(p.startedOn)}' : '${day(p.startedOn)} to ${day(p.stoppedOn!)}'}'
          '${p.notes == null || p.notes!.trim().isEmpty ? '' : '. ${clean(p.notes)}'}',
  ];

  // Factors: every bucket row, with the app's own headline rows marked rather than repeated in a
  // second table. Matches what tools/report.html settled on after review.
  List<ReportFactorGroup> groups(Map<String, List<FactorRow>> factors, List<TopFactor> top) {
    final topKeys = {for (final t in top) '${t.factor}|${t.condition}'};
    return [
      for (final entry in factors.entries)
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
  }

  final factorGroups = groups(corr.factors, corr.topFactors);

  // Days tracked and migraine days vs clear days (backlog #16).
  String? tracked;
  final tDays = dash.tracked;
  if (tDays != null) {
    tracked = 'Days tracked, last 30 days: ${tDays.last30} (${tDays.migraineLast30} with a migraine, '
        '${tDays.clearLast30} checked in as clear, ${30 - tDays.last30} not recorded). Since the first '
        'check-in on ${df.format(tDays.firstCheckin)}: ${tDays.sinceFirstCheckin} of '
        '${tDays.daysSinceFirstCheckin} days.';
  }
  ReportTrackedFactors? trackedFactors;
  final tFactors = dash.trackedFactors;
  if (tFactors != null) {
    trackedFactors = ReportTrackedFactors(
      available: tFactors.available,
      reason: tFactors.reason,
      window: '${tFactors.migraineDays} migraine days and ${tFactors.clearDays} clear days since the first '
          'check-in (${tFactors.trackedDays} tracked days).',
      groups: groups(tFactors.factors, tFactors.topFactors),
      caveats: tFactors.caveats,
    );
  }

  final sorted = [...events]..sort((x, y) => y.startedAt.compareTo(x.startedAt));
  final dfRow = DateFormat('d MMM yyyy');
  final tf = DateFormat('HH:mm');
  final eventRows = <ReportEventRow>[
    for (final e in sorted)
      ReportEventRow(
        date: dfRow.format(e.startedWall),
        time: tf.format(e.startedWall),
        severity: hasHeadache(e.headachePresent) ? (e.severity?.toString() ?? '-') : 'none',
        duration: e.endedAt == null
            ? 'ongoing'
            : (e.endedAt!.isBefore(e.startedAt)
                ? '-'
                : _fmtDuration(e.endedAt!.difference(e.startedAt))),
        aura: e.auraPresent == null ? '-' : (e.auraPresent! ? 'yes' : 'no'),
        headLocations: clean(decodeStringList(e.locationHead).join(', ')),
        symptoms: clean(decodeStringList(e.symptoms).join(', ')),
        triggers: clean(decodeStringList(e.triggersSuspected).join(', ')),
        meds: clean([
          decodeMeds(e.medsTaken)
              .map((m) => [m.name, if (m.dose != null && m.dose!.isNotEmpty) m.dose!].join(' '))
              .join(', '),
          // Non-drug relief (backlog #19) shares the column, on its own line.
          if (decodeRelief(e.reliefTried).isNotEmpty)
            'Relief: ${decodeRelief(e.reliefTried).map((r) => r.name).join(', ')}',
        ].where((x) => x.isNotEmpty).join('\n')),
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
    impact: impact,
    tracked: tracked,
    trackedFactors: trackedFactors,
    withoutHeadache: withoutHeadache,
    triggerFrequency: bars(dash.triggerFrequency),
    symptomFrequency: bars(dash.symptomFrequency),
    medications: medications,
    relief: relief,
    medicationDays: medicationDays,
    preventives: preventives,
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
