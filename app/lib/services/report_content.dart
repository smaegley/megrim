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
import '../l10n/data_labels.dart';
import '../l10n/formats.dart';
import '../l10n/l10n.dart';
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

/// A computed decimal (already rounded to a few places), as the report prints it: always at least
/// one decimal ("3.0", "12.5", "33.33"), with the locale's separator.
String reportDecimal(Formats f, double v) => NumberFormat('0.0##', f.locale).format(v);

String _fmtDuration(AppLocalizations l, Formats f, Duration d) {
  final h = d.inMinutes / 60.0;
  if (h < 1) return l.reportMinutesShort(d.inMinutes);
  if (h < 24) return l.reportHoursShort(reportDecimal(f, (h * 10).round() / 10));
  return l.reportDaysHoursShort(d.inDays, d.inHours % 24);
}

/// The report in [l10n]'s language (decision D1: the app's own), English when null. Stored
/// values (default triggers, symptoms, factor buckets) are translated for display only.
ReportContent buildReportContent({
  required DashboardResult dash,
  required CorrelationResult corr,
  required List<MigraineEvent> events,
  required String appVersion,
  required DateTime now,
  String? homeLabel,
  bool weatherEnabled = true,
  bool Function(int rune)? canRender,
  AppLocalizations? l10n,
}) {
  final l = l10n ?? englishL10n;
  final fmt = Formats.forL10n(l);
  String dec(double v) => reportDecimal(fmt, v);
  String label(String v) => dataLabel(l, v);

  var anySubstituted = false;
  String clean(String? s) {
    if (s == null || s.isEmpty) return '';
    if (canRender == null) return s;
    final r = sanitiseForFont(s, canRender);
    if (r.substituted) anySubstituted = true;
    return r.text;
  }

  final s = dash.summary;

  final subtitleParts = <String>[
    l.reportEntryCount(s.totalEvents),
    if (homeLabel != null && homeLabel.isNotEmpty) clean(homeLabel),
    if (s.firstEvent != null && s.lastEvent != null)
      l.reportDateRange(fmt.date(s.firstEvent!), fmt.date(s.lastEvent!)),
    l.reportGenerated(fmt.date(now)),
    l.reportAppVersion(appVersion),
  ];

  final summary = <ReportStat>[
    ReportStat(l.reportStatEntries, '${s.totalEvents}'),
    ReportStat(l.reportStatYearsTracked, dec(s.yearsTracked)),
    ReportStat(l.reportStatAvgSeverity,
        s.avgSeverity != null ? l.reportSeverityOutOf10(dec(s.avgSeverity!)) : '-'),
    ReportStat(l.reportStatAvgDuration,
        s.avgDurationHours != null ? l.reportHoursShort(dec(s.avgDurationHours!)) : '-'),
    ReportStat(l.reportStatAvgInterval,
        s.avgIntervalDays != null ? l.reportDaysShort(dec(s.avgIntervalDays!)) : '-'),
    ReportStat(l.reportStatPerYear, dec(s.eventsPerYear)),
    // Backlog #17: days, not entries — the figure a clinician asks for first.
    ReportStat(l.reportStatMigraineDays30, '${dash.migraineDaysLast30}'),
  ];

  List<ReportBar> bars(List<LabeledCount> list) =>
      [for (final c in list) ReportBar(clean(label(c.label)), c.count)];

  String monthLabel(int year, int month) {
    final m = DateTime(year, month);
    final text = fmt.monthYearShort(m);
    return m == DateTime(now.year, now.month) ? l.reportMonthMarkedInProgress(text) : text;
  }

  // Last 12 months of migraine days (backlog #17), the current month marked as unfinished.
  final recentMonths = dash.migraineDaysByMonth.length > 12
      ? dash.migraineDaysByMonth.sublist(dash.migraineDaysByMonth.length - 12)
      : dash.migraineDaysByMonth;
  final recentWithout = recentMonths.fold<int>(0, (n, m) => n + m.daysWithoutHeadache);

  final charts = <ReportChart>[
    if (recentMonths.isNotEmpty)
      ReportChart(
        title: l.reportChartMonthly,
        note: [
          l.reportMonthlyNote,
          if (dash.avgMigraineDaysLast3Months != null)
            l.reportMonthlyAverage(dec(dash.avgMigraineDaysLast3Months!)),
          if (recentWithout > 0) l.reportMonthlyWithoutHeadache(recentWithout),
          l.reportMonthInProgress,
        ].join(' '),
        bars: [for (final m in recentMonths) ReportBar(monthLabel(m.year, m.month), m.days)],
      ),
    if (dash.byYear.isNotEmpty)
      ReportChart(
        title: l.reportChartByYear,
        bars: [for (final y in dash.byYear) ReportBar('${y.year}', y.count)],
      ),
    ReportChart(title: l.reportChartByDayOfWeek, bars: bars(dash.byDayOfWeek)),
    ReportChart(title: l.reportChartBySeason, bars: bars(dash.bySeason)),
    ReportChart(title: l.reportChartByTimeOfDay, bars: bars(dash.byTimeOfDay)),
    ReportChart(title: l.reportChartByDaylight, bars: bars(dash.byDaylight)),
    ReportChart(
      title: l.reportChartPressure,
      note: weatherEnabled ? null : l.reportChartPressureOff,
      bars: bars(dash.pressureDelta),
    ),
    ReportChart(title: l.reportChartByMoon, bars: bars(dash.byMoonPhase)),
  ];

  String? away;
  final a = dash.awayFromHome;
  if (a != null) {
    final km = a.thresholdKm.round();
    if (a.awayEvents == 0) {
      away = l.reportAwayAllHome(a.locatedEvents, km);
    } else if (a.awayPlaces.isEmpty) {
      away = l.reportAwaySome(a.awayEvents, a.locatedEvents, dec(a.awayPct), km);
    } else {
      away = l.reportAwaySomePlaces(a.awayEvents, a.locatedEvents, dec(a.awayPct), km,
          a.awayPlaces.take(5).map((p) => l.reportAwayPlace(clean(p.label), p.count)).join(', '));
    }
  }

  // Impact on the day (backlog #22a).
  String? impact;
  final i = dash.impact;
  if (i != null) {
    impact = [
      l.reportImpact(l.reportDayCount(i.unableLast30), l.reportDayCount(i.reducedLast30),
          i.recordedLast30, dash.migraineDaysLast30),
      if (i.avgUnableLast3Months != null)
        l.reportImpactAverage(dec(i.avgUnableLast3Months!), dec(i.avgReducedLast3Months ?? 0)),
    ].join(' ');
  }

  // Attacks without headache (backlog #26).
  ReportWithoutHeadache? withoutHeadache;
  final w = dash.withoutHeadache;
  if (w != null) {
    withoutHeadache = ReportWithoutHeadache(
      summary: [
        l.reportWithoutHeadacheSummary(
            w.events, w.totalEvents, dec(w.pct), w.withAura, w.withVertigo, w.other),
        if (w.medianDurationHours != null)
          l.reportWithoutHeadacheMedian(dec(w.medianDurationHours!)),
      ].join(' '),
      byKind: [
        ReportBar(l.reportWithAura, w.withAura),
        ReportBar(l.reportWithVertigo, w.withVertigo),
        ReportBar(l.reportOther, w.other),
      ],
      symptoms: bars(w.symptoms),
    );
  }

  // Medications and relief (backlog #19), from the dashboard so the report and the Analytics tab
  // count them the same way. Relief names may be the English defaults; medication names are typed.
  ReportMedRow medRow(HelpedRow r) => ReportMedRow(
        name: clean(r.relief ? label(r.name) : r.name),
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
    final months = md.byMonth.length > 12 ? md.byMonth.sublist(md.byMonth.length - 12) : md.byMonth;
    final classes = [
      for (final c in [...MedClass.all, kUnclassified])
        if (months.any((m) => m.byClass.containsKey(c))) c,
    ];
    final breakdown =
        md.byClassLast30.entries.map((e) => l.reportMedClassDays(medClassName(l, e.key), e.value));
    final last30 = l.reportDayCount(md.last30);
    medicationDays = ReportMedicationDays(
      summary: breakdown.isEmpty
          ? l.reportMedDaysSummary(last30)
          : l.reportMedDaysSummaryByClass(last30, breakdown.join(', ')),
      headers: [l.reportColumnMonth, l.reportColumnAny, for (final c in classes) medClassName(l, c)],
      rows: [
        for (final m in months)
          [
            monthLabel(m.year, m.month),
            '${m.days}',
            for (final c in classes) '${m.byClass[c] ?? 0}',
          ],
      ],
      notice: md.notice == null
          ? const []
          : [
              l.overuseNoticeTitle,
              for (final m in md.notice!)
                for (final r in m.levelsReached)
                  l.reportOveruseMonthReason(
                      fmt.monthYearShort(DateTime(m.year, m.month)), levelReason(l, m, r)),
              l.overuseNoticeBody,
            ],
      unclassified: md.unclassifiedNames.isEmpty
          ? null
          : l.reportMedUnclassified(md.unclassifiedNames.map(clean).join(', ')),
    );
  }

  String day(String iso) {
    final d = parseIsoDay(iso);
    return d == null ? iso : fmt.date(d);
  }

  final preventives = [
    for (final p in dash.preventives)
      () {
        final name = '${clean(p.name)}${p.dose == null ? '' : ' ${clean(p.dose)}'}';
        final line = p.stoppedOn == null
            ? l.reportPreventiveSince(name, day(p.startedOn))
            : l.reportPreventiveRange(name, day(p.startedOn), day(p.stoppedOn!));
        return p.notes == null || p.notes!.trim().isEmpty
            ? line
            : l.reportPreventiveNotes(line, clean(p.notes));
      }(),
  ];

  // Factors: every bucket row, with the app's own headline rows marked rather than repeated in a
  // second table. Matches what tools/report.html settled on after review. Factor names and
  // buckets are matched in English and translated for display.
  List<ReportFactorGroup> groups(Map<String, List<FactorRow>> factors, List<TopFactor> top) {
    final topKeys = {for (final t in top) '${t.factor}|${t.condition}'};
    return [
      for (final entry in factors.entries)
        if (entry.value.isNotEmpty)
          ReportFactorGroup(
            name: clean(label(entry.key)),
            rows: [
              for (final r in entry.value)
                ReportFactorRow(
                  bucket: clean(label(r.bucket)),
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
    tracked = l.reportTracked(
      tDays.last30,
      tDays.migraineLast30,
      tDays.clearLast30,
      30 - tDays.last30,
      fmt.date(tDays.firstCheckin),
      tDays.sinceFirstCheckin,
      tDays.daysSinceFirstCheckin,
    );
  }
  ReportTrackedFactors? trackedFactors;
  final tFactors = dash.trackedFactors;
  if (tFactors != null) {
    trackedFactors = ReportTrackedFactors(
      available: tFactors.available,
      reason: tFactors.reasonIn(l),
      window: l.reportTrackedWindow(tFactors.migraineDays, tFactors.clearDays, tFactors.trackedDays),
      groups: groups(tFactors.factors, tFactors.topFactors),
      caveats: tFactors.caveatsIn(l),
    );
  }

  String labels(String? json) => clean(decodeStringList(json).map(label).join(', '));

  final sorted = [...events]..sort((x, y) => y.startedAt.compareTo(x.startedAt));
  final eventRows = <ReportEventRow>[
    for (final e in sorted)
      ReportEventRow(
        date: fmt.date(e.startedWall),
        time: fmt.time(e.startedWall),
        severity: hasHeadache(e.headachePresent)
            ? (e.severity?.toString() ?? '-')
            : l.reportSeverityNone,
        duration: e.endedAt == null
            ? l.reportDurationOngoing
            : (e.endedAt!.isBefore(e.startedAt)
                ? '-'
                : _fmtDuration(l, fmt, e.endedAt!.difference(e.startedAt))),
        aura: e.auraPresent == null ? '-' : (e.auraPresent! ? l.reportYes : l.reportNo),
        headLocations: labels(e.locationHead),
        symptoms: labels(e.symptoms),
        triggers: labels(e.triggersSuspected),
        meds: clean([
          decodeMeds(e.medsTaken)
              .map((m) => [m.name, if (m.dose != null && m.dose!.isNotEmpty) m.dose!].join(' '))
              .join(', '),
          // Non-drug relief (backlog #19) shares the column, on its own line.
          if (decodeRelief(e.reliefTried).isNotEmpty)
            l.reportReliefLine(decodeRelief(e.reliefTried).map((r) => label(r.name)).join(', ')),
        ].where((x) => x.isNotEmpty).join('\n')),
        notes: clean(e.notes),
      ),
  ];

  final footnotes = <String>[
    if (!corr.factors.containsKey('Pressure Δ 24h (hPa)')) l.reportFootnotePressure,
    l.legalWeatherAttribution,
  ];

  // Built last: `clean` sets the flag as it goes, so this has to come after every call to it.
  if (anySubstituted) footnotes.insert(0, l.reportFootnoteFont);

  return ReportContent(
    title: l.reportTitle,
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
    factorsReason: corr.reasonIn(l),
    factorsWindow: corr.available
        ? l.reportFactorsWindow(corr.totalMigraineDays, corr.totalDaysInRange, dec(corr.baseRatePct))
        : '',
    factorGroups: factorGroups,
    caveats: corr.caveatsIn(l),
    events: eventRows,
    footnotes: footnotes,
    methods: l.reportMethods,
    disclaimer: l.legalMedicalDisclaimer,
  );
}
