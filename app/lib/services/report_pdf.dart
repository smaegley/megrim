/// Draws a [ReportContent] as a PDF (backlog #12).
///
/// Deliberately dumb: every string, every ordering and every gating decision was already made in
/// `report_content.dart`, which is pure and tested. This file only lays out what it is given, so
/// the report cannot disagree with the Analytics tab about a number.
///
/// Fonts are passed in rather than loaded here, so this stays testable off-device: the PDF
/// built-in fonts cover Latin-1 only and would silently drop the app's own "≥ 14 h" and
/// "Pressure Δ 24h" labels, never mind notes written in Polish, Greek or Cyrillic.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/formats.dart';
import '../l10n/l10n.dart';
import 'report_content.dart';

/// Ink colours. Greys rather than the app's purple: this is printed, often in black and white, and
/// a clinician's copy should not depend on colour to be readable.
const PdfColor _ink = PdfColor.fromInt(0xFF1C2733);
const PdfColor _muted = PdfColor.fromInt(0xFF5B6876);
const PdfColor _rule = PdfColor.fromInt(0xFFBFC7D1);
const PdfColor _bar = PdfColor.fromInt(0xFF8E9BB3);
const PdfColor _panel = PdfColor.fromInt(0xFFF1F3F6);

/// Width of a bar as integer flex out of 1000 — the PDF widget set has no fractional sizing.
int filledFlex(int count, int max) =>
    max <= 0 ? 0 : (count / max * 1000).round().clamp(0, 1000);

/// [l10n] gives the headings, column names and notes; pass the one the content was built with.
/// English when null.
Future<Uint8List> renderReportPdf(
  ReportContent c, {
  required ByteData regular,
  required ByteData bold,
  AppLocalizations? l10n,
}) async {
  final l = l10n ?? englishL10n;
  final fmt = Formats.forL10n(l);
  String pct(num v) => l.reportPercent(v is double ? reportDecimal(fmt, v) : '$v');
  final fontRegular = pw.Font.ttf(regular);
  final fontBold = pw.Font.ttf(bold);

  final doc = pw.Document(
    title: c.title,
    theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold).copyWith(
      defaultTextStyle: pw.TextStyle(font: fontRegular, fontSize: 9, color: _ink),
    ),
  );

  pw.Widget heading(String text) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.7)),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(font: fontBold, fontSize: 12, color: _ink)),
      );

  pw.Widget note(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(text,
            style: pw.TextStyle(font: fontRegular, fontSize: 8, color: _muted)),
      );

  // Horizontal bars, drawn as rectangles: no chart library, and they survive a black-and-white
  // print, which a colour-coded chart would not.
  pw.Widget barChart(List<ReportBar> bars) {
    if (bars.isEmpty) return note(l.reportNoData);
    final max = bars.map((b) => b.count).fold<int>(0, (a, b) => a > b ? a : b);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final b in bars)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 78,
                  child: pw.Text(b.label,
                      style: const pw.TextStyle(fontSize: 8, color: _muted)),
                ),
                // Two Expandeds in proportion rather than a fractional box: the PDF widget set
                // has no FractionallySizedBox, and integer flex is exact enough at this size.
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (filledFlex(b.count, max) > 0)
                        pw.Expanded(
                          flex: filledFlex(b.count, max),
                          child: pw.Container(height: 8, color: _bar),
                        ),
                      if (filledFlex(b.count, max) < 1000)
                        pw.Expanded(
                          flex: 1000 - filledFlex(b.count, max),
                          child: pw.Container(height: 8, color: _panel),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 26,
                  child: pw.Text('${b.count}',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget table(List<String> headers, List<List<String>> rows,
      {List<int>? flex, List<bool>? rightAlign}) {
    pw.Widget cell(String text, int i, {bool header = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 3),
          child: pw.Text(
            text,
            textAlign:
                (rightAlign != null && rightAlign[i]) ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              font: header ? fontBold : fontRegular,
              fontSize: 8,
              color: header ? _muted : _ink,
            ),
          ),
        );
    return pw.Table(
      border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _rule, width: 0.4),
          bottom: pw.BorderSide(color: _rule, width: 0.4)),
      columnWidths: {
        for (var i = 0; i < headers.length; i++)
          i: pw.FlexColumnWidth((flex?[i] ?? 1).toDouble()),
      },
      children: [
        // repeat: the header row is redrawn when a table spans a page break.
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 0.7)),
          ),
          children: [
            for (var i = 0; i < headers.length; i++) cell(headers[i], i, header: true),
          ],
        ),
        for (final r in rows)
          pw.TableRow(children: [for (var i = 0; i < r.length; i++) cell(r[i], i)]),
      ],
    );
  }

  pw.Widget helpedTable(String what, List<ReportMedRow> rows) => table(
        [
          what,
          l.reportColumnTaken,
          l.reportColumnHelped,
          l.reportColumnDidnt,
          l.reportColumnUnknown,
          l.reportColumnHelpedPct,
        ],
        [
          for (final m in rows)
            [
              m.name,
              '${m.taken}',
              '${m.helped}',
              '${m.notHelped}',
              '${m.unknown}',
              m.helpedPct == null ? '-' : pct(m.helpedPct!),
            ],
        ],
        flex: const [4, 1, 1, 1, 1, 1],
        rightAlign: const [false, true, true, true, true, true],
      );

  final pages = <pw.Widget>[
    // ── header ──────────────────────────────────────────────────────────────
    pw.Text(c.title, style: pw.TextStyle(font: fontBold, fontSize: 20)),
    pw.SizedBox(height: 2),
    pw.Text(c.subtitle, style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
    pw.SizedBox(height: 4),
    pw.Divider(color: _ink, thickness: 1),

    // ── summary ─────────────────────────────────────────────────────────────
    heading(l.reportHeadingSummary),
    pw.Row(
      children: [
        for (final s in c.summary)
          pw.Expanded(
            child: pw.Container(
              // Fixed height with room for a two-line label, so a tile whose label wraps
              // ("Migraine days, last 30 d") isn't taller than its neighbours.
              height: 52,
              margin: const pw.EdgeInsets.only(right: 4),
              padding: const pw.EdgeInsets.all(6),
              color: _panel,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(s.value,
                      style: pw.TextStyle(font: fontBold, fontSize: 13)),
                  pw.Text(s.label,
                      style: const pw.TextStyle(fontSize: 7, color: _muted)),
                ],
              ),
            ),
          ),
      ],
    ),
    if (c.awayFromHome != null) ...[
      pw.SizedBox(height: 6),
      pw.Text(c.awayFromHome!, style: const pw.TextStyle(fontSize: 8.5)),
    ],
    if (c.impact != null) ...[
      pw.SizedBox(height: 6),
      pw.Text(c.impact!, style: const pw.TextStyle(fontSize: 8.5)),
    ],
    if (c.tracked != null) ...[
      pw.SizedBox(height: 6),
      pw.Text(c.tracked!, style: const pw.TextStyle(fontSize: 8.5)),
    ],

    // ── attacks without headache (backlog #26) ──────────────────────────────
    if (c.withoutHeadache != null) ...[
      heading(l.reportHeadingWithoutHeadache),
      pw.Text(c.withoutHeadache!.summary, style: const pw.TextStyle(fontSize: 8.5)),
      note(l.reportWithoutHeadacheNote),
      pw.SizedBox(height: 4),
      barChart(c.withoutHeadache!.byKind),
      if (c.withoutHeadache!.symptoms.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(l.reportTheirSymptoms, style: pw.TextStyle(font: fontBold, fontSize: 9)),
        pw.SizedBox(height: 2),
        barChart(c.withoutHeadache!.symptoms),
      ],
    ],

    // ── patterns ────────────────────────────────────────────────────────────
    heading(l.reportHeadingPatterns),
    note(l.reportPatternsNote),
    for (final chart in c.charts) ...[
      pw.SizedBox(height: 6),
      pw.Text(chart.title, style: pw.TextStyle(font: fontBold, fontSize: 9)),
      if (chart.note != null) note(chart.note!),
      pw.SizedBox(height: 2),
      barChart(chart.bars),
    ],

    if (c.triggerFrequency.isNotEmpty) ...[
      heading(l.reportHeadingTriggers),
      note(l.reportTriggersNote),
      barChart(c.triggerFrequency),
    ],

    if (c.symptomFrequency.isNotEmpty) ...[
      heading(l.reportHeadingSymptoms),
      note(l.reportSymptomsNote),
      barChart(c.symptomFrequency),
    ],

    // ── acute-medication days (backlog #18) ─────────────────────────────────
    if (c.medicationDays != null) ...[
      heading(l.reportHeadingMedDays),
      pw.Text(c.medicationDays!.summary, style: const pw.TextStyle(fontSize: 8.5)),
      if (c.medicationDays!.notice.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          color: _panel,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(c.medicationDays!.notice.first,
                  style: pw.TextStyle(font: fontBold, fontSize: 9)),
              for (final line in c.medicationDays!.notice.skip(1))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(line, style: const pw.TextStyle(fontSize: 8)),
                ),
            ],
          ),
        ),
      ],
      pw.SizedBox(height: 4),
      table(
        c.medicationDays!.headers,
        c.medicationDays!.rows,
        flex: [3, for (var i = 1; i < c.medicationDays!.headers.length; i++) 2],
        rightAlign: [false, for (var i = 1; i < c.medicationDays!.headers.length; i++) true],
      ),
      note(l.reportMedDaysNote),
      if (c.medicationDays!.unclassified != null) note(c.medicationDays!.unclassified!),
    ],

    if (c.preventives.isNotEmpty) ...[
      heading(l.reportHeadingPreventives),
      for (final line in c.preventives)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text(line, style: const pw.TextStyle(fontSize: 8.5)),
        ),
    ],

    if (c.medications.isNotEmpty) ...[
      heading(l.reportHeadingMedications),
      helpedTable(l.reportColumnMedication, c.medications),
      note(l.reportMedicationsNote),
    ],

    // ── non-drug relief (backlog #19) ───────────────────────────────────────
    if (c.relief.isNotEmpty) ...[
      heading(l.reportHeadingRelief),
      helpedTable(l.reportColumnRelief, c.relief),
      note(l.reportReliefNote),
    ],
  ];

  final factorPages = <pw.Widget>[
    heading(l.reportHeadingFactors),
    pw.Container(
      padding: const pw.EdgeInsets.all(7),
      color: _panel,
      child: pw.Text(l.reportFactorsReadFirst, style: const pw.TextStyle(fontSize: 8)),
    ),
    pw.SizedBox(height: 6),
    if (!c.factorsAvailable)
      pw.Text(c.factorsReason ?? l.reportNotEnoughData,
          style: const pw.TextStyle(fontSize: 8.5))
    else ...[
      pw.Text(c.factorsWindow, style: const pw.TextStyle(fontSize: 8.5)),
      for (final g in c.factorGroups) ...[
        pw.SizedBox(height: 8),
        pw.Text(g.name, style: pw.TextStyle(font: fontBold, fontSize: 9)),
        pw.SizedBox(height: 2),
        table(
          [
            l.reportColumnBucket,
            l.reportColumnMigraineDays,
            l.reportColumnAllDays,
            l.reportColumnRate,
            l.reportColumnOddsRatio,
          ],
          [
            for (final r in g.rows)
              [
                '${r.bucket}${r.isTop ? '  *' : ''}',
                '${r.migraineDays}',
                '${r.totalDays}',
                pct(r.ratePct),
                fmt.decimal(r.oddsRatio, 2),
              ],
          ],
          flex: const [3, 2, 2, 2, 2],
          rightAlign: const [false, true, true, true, true],
        ),
      ],
      pw.SizedBox(height: 4),
      note(l.reportFactorsStarNote),
      for (final caveat in c.caveats) note(l.reportCaveatItem(caveat)),
    ],
    // ── migraine days vs clear days (backlog #16) ─────────────────────────
    if (c.trackedFactors case final t?) ...[
      // One block, so the heading can't be left alone at the foot of a page.
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            heading(l.reportHeadingTracked),
            note(l.reportTrackedNote),
            pw.SizedBox(height: 4),
            pw.Text(t.available ? t.window : t.reason ?? l.reportNotEnoughData,
                style: const pw.TextStyle(fontSize: 8.5)),
          ],
        ),
      ),
      if (t.available) ...[
        for (final g in t.groups) ...[
          pw.SizedBox(height: 8),
          pw.Text(g.name, style: pw.TextStyle(font: fontBold, fontSize: 9)),
          pw.SizedBox(height: 2),
          table(
            [
              l.reportColumnRecorded,
              l.reportColumnMigraineDays,
              l.reportColumnTrackedDays,
              l.reportColumnRate,
              l.reportColumnOddsRatio,
            ],
            [
              for (final r in g.rows)
                [
                  '${r.bucket}${r.isTop ? '  *' : ''}',
                  '${r.migraineDays}',
                  '${r.totalDays}',
                  pct(r.ratePct),
                  fmt.decimal(r.oddsRatio, 2),
                ],
            ],
            flex: const [3, 2, 2, 2, 2],
            rightAlign: const [false, true, true, true, true],
          ),
        ],
        pw.SizedBox(height: 4),
        for (final caveat in t.caveats) note(l.reportCaveatItem(caveat)),
      ],
    ],
  ];

  final eventPages = <pw.Widget>[
    heading(l.reportHeadingEntries),
    note(l.reportEntriesNote),
    table(
      [
        l.reportColumnDate,
        l.reportColumnTime,
        l.reportColumnSev,
        l.reportColumnDuration,
        l.reportColumnAura,
        l.reportColumnHead,
        l.reportColumnSymptoms,
        l.reportColumnTriggers,
        l.reportColumnMeds,
        l.reportColumnNotes,
      ],
      [
        for (final e in c.events)
          [
            e.date,
            e.time,
            e.severity,
            e.duration,
            e.aura,
            e.headLocations,
            e.symptoms,
            e.triggers,
            e.meds,
            e.notes,
          ],
      ],
      // Widths tuned against the rendered page: at 8pt the 'Duration' and 'Aura' headers wrap if
      // their columns are any narrower, which looks like a defect even though the data fits.
      // In points across the 531pt A4 text width, measured against Noto Sans at 8pt plus the 6pt
      // cell padding: "28 Sep 2026" needs ~52, the bold "Duration" header ~42, "none" (Sev for an
      // attack without headache) ~26, the "Symptoms" header ~48. Narrower and they wrap. Meds
      // needs ~80 for a long generic name ("Metoclopramide") without breaking mid-word, and holds
      // the relief line too (backlog #19).
      flex: const [54, 28, 27, 43, 27, 60, 74, 72, 80, 66],
      rightAlign: const [false, false, true, false, false, false, false, false, false, false],
    ),
  ];

  final closing = <pw.Widget>[
    heading(l.reportHeadingMethods),
    pw.Text(c.methods, style: const pw.TextStyle(fontSize: 8, color: _muted)),
    for (final f in c.footnotes) ...[pw.SizedBox(height: 4), note(f)],
    heading(l.reportHeadingDisclaimer),
    pw.Text(c.disclaimer, style: const pw.TextStyle(fontSize: 8)),
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          l.reportPageOf(ctx.pageNumber, ctx.pagesCount),
          style: const pw.TextStyle(fontSize: 7.5, color: _muted),
        ),
      ),
      build: (ctx) => [
        ...pages,
        // The factor tables and the entry log each start on a fresh page: they're the two parts a
        // reader is most likely to flip straight to.
        pw.NewPage(),
        ...factorPages,
        pw.NewPage(),
        ...eventPages,
        ...closing,
      ],
    ),
  );

  return doc.save();
}
