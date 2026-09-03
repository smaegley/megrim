# How Megrim's analytics work

This page explains, in plain language, how the numbers on the Analytics tab are calculated —
so you know exactly what they mean and, just as importantly, what they don't. Everything below
runs entirely on your device, over your own log. The implementation is open source:
[`dashboard.dart`](../app/lib/analytics/dashboard.dart) and
[`correlations.dart`](../app/lib/analytics/correlations.dart), with tests that pin the math to
independently computed reference values.

Megrim is a personal diary, **not a medical device**. Nothing here diagnoses, treats, or
predicts anything.

## Two different kinds of analytics

**1. The descriptive charts** (by year, day of week, time of day, season, moon phase, daylight,
pressure change) are plain counts: how many of your logged migraines fall into each bucket.
No statistics, no modeling — just your data, grouped. A tall bar means "you logged more
migraines there," nothing more. In particular, a tall Monday bar doesn't account for the fact
that every week contains a Monday; that's what the second kind is for.

**2. Top Suspected Factors** is the only place Megrim does real statistics, and it works like
this.

## How Suspected Factors are calculated

**Migraine-days.** The unit of analysis is a *day*, not an entry. Every calendar day inside your
study window is either a migraine-day (you logged at least one migraine that day, or a
multi-day migraine covered it) or a non-migraine-day. Logging three entries on one bad day
counts once. The **study window** runs from your first logged migraine to your most recent one.

**The comparison.** For each factor bucket (say, "Friday" or "pressure fell more than 10 hPa"),
Megrim builds a 2×2 table: migraine-days in the bucket, migraine-days outside it,
non-migraine-days in the bucket, non-migraine-days outside it. That requires knowing the bucket
for *every* day in the window, not just migraine days:

- **Calendar factors** (day of week, month, season) are computed exactly — every date has a
  known weekday and season.
- **Moon phase and daylight** are computed astronomically for every day in the window, on the
  device.
- **Pressure change** needs real weather history for the non-migraine days, so it's only
  available if you opted into weather enrichment; the app fetches a one-time daily-pressure
  history for your home location from Open-Meteo and caches it.

**The odds ratio.** From the 2×2 table Megrim computes an odds ratio (OR): how much more likely
a day in that bucket was to be a migraine-day, compared with a day outside it, *in your log*.
OR = 1.0 means the bucket made no difference. OR = 2.0 means the odds of a migraine-day were
about twice as high in the bucket. Before dividing, 0.5 is added to all four cells of every
table (the Haldane–Anscombe correction). This keeps the math from blowing up when a cell is
zero, at the cost of slightly shrinking every value toward 1.0 — one more reason values near
1.0 should be read as "no signal."

**What gets shown.** A factor bucket appears in Top Suspected Factors only if it covers at
least 3 of your migraine-days and its OR is above 1.0; the strongest 8 are shown, sorted by OR.
The bars encode each OR relative to the strongest one shown. Buckets below the threshold aren't
"disproven" — there just isn't enough data to say anything.

## What this can and cannot tell you

- **Association is not causation.** A high OR for Fridays doesn't mean Fridays cause migraines —
  maybe your Fridays share a schedule, a food, or a sleep pattern. The tool exists to generate
  hypotheses worth discussing with a clinician, not conclusions.
- **Small samples are noisy.** With a few dozen migraine-days, ORs jump around a lot as you add
  entries. The card always shows how many days the analysis is based on.
- **Many factors are tested at once.** When dozens of buckets are examined, some will look
  elevated purely by chance (the multiple-comparisons problem). Megrim does not apply
  significance testing or corrections for this — treat single stand-out buckets skeptically,
  and give more weight to patterns that persist as your log grows.
- **No prediction.** Megrim only looks backward at what you logged. It does not forecast
  migraines and makes no claims about tomorrow.

These same caveats are shown in the app, on the Suspected Factors card itself, every time
results are displayed.

## Verifying this yourself

Because Megrim is GPL-licensed, none of this has to be taken on trust: the analysis code is in
[`app/lib/analytics/`](../app/lib/analytics/), the golden tests pin its outputs, and your data
is fully exportable (JSON/CSV) if you want to re-run the numbers with your own tools.
