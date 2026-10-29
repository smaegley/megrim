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

## Migraine days per month

The **Migraine days per month** card counts *days*, not entries: the number neurologists use to
track how often migraines happen and whether a preventive treatment is working.

- A **migraine day** is a calendar day covered by at least one logged migraine. Two entries on
  the same day count once. A migraine that runs from Friday into Sunday counts three days: each
  day from its start date to its end date. This is the same rule the History calendar uses.
- Each entry's days are read **in the time zone it was logged in**, so a migraine logged while
  travelling stays on the day it happened there.
- A migraine with **no end time yet** counts only its start day, so an entry you forgot to end
  doesn't inflate a month.
- **Last 30 days** is today and the 29 days before it.
- **Avg/month, last 3 months** is the average over the three most recent *complete* calendar
  months; the current month is left out because it isn't over. It stays blank until three
  complete months have passed since your first entry, so months before you started logging
  can't pull the average down.
- The chart shows every month from your first entry to now, **including months with no
  migraines**, because a migraine-free month is information too. The current month is marked
  as still in progress.

Like the other charts, this is a count of what you logged. A month with no entries could be a
month without migraines or a month you didn't log; the app can't tell the two apart.

### Attacks without headache

An entry can be marked **"Headache? No"**: an aura with no pain after it, an episode of vertigo,
or the tired, foggy phase of an attack with the pain never arriving. These are recognised parts
of migraine: ICHD-3 1.2.1.2 *typical aura without headache*, ICHD-3 appendix A1.6.6 *vestibular
migraine* (often without headache), and the prodrome and postdrome, where fatigue is one of the
most common symptoms. The app records what happened and does not name a type.

- **They are migraine days.** They count in Migraine days per month, and the card says how many
  of the last 30 days had *only* attacks without headache ("including N without headache"); each
  month's bar shows that part in a second colour. A day with both kinds counts once, as a
  headache day.
- **They are in Suspected Factors** like any other entry: the weather and calendar factors don't
  depend on whether it hurt.
- **They have no severity.** Severity rates pain, so the slider is hidden and the average severity
  covers headache attacks only. Their burden goes in **Impact** instead.
- Entries from before this field existed read as "Not sure", which counts as a headache, so
  older data counts exactly as it did.
- The report lists them in their own section: how many, their share of all entries, split into
  **with aura** (aura recorded), **with vertigo or dizziness** (either symptom ticked, no aura)
  and **other**, their most common symptoms and their median length. An entry with both aura and
  vertigo counts as "with aura", the more specific diagnosis to point a clinician at.

### Impact on the day

Each entry can record whether you **functioned normally**, had **reduced** function, or were
**unable** to function. Impact is counted in days on the same rule as migraine days: each
migraine day takes the worst impact recorded on any entry covering it. The card shows the last 30
days and, once three complete months have passed since the first impact you recorded, the
monthly average over them (counting from your first entry instead would average in months when
the field didn't exist yet, and read as zero bad days). It also says on how
many of the last 30 days' migraine days an impact was recorded at all, so a low count can be told
apart from a field that is rarely filled in.

### Symptoms

**Most common symptoms** is a plain count, like Most-tagged triggers: how many entries each
symptom was ticked on. It is not a correlation, because symptoms are only recorded on migraine
days.

## Medications

### Acute medication days and the overuse notice

Medications logged on entries are the ones taken **for an attack** (acute). Each can be given a
**class** in Settings › Medications, or when its name is first entered: triptan, ergot, opioid,
combination pain reliever, simple pain reliever, gepant, ditan, anti-nausea, or other. A name
with no class is counted but never checked against the levels below. Classes are kept by name,
apart from the suggestion list, so renaming a suggestion gives the new name the class and the old
name keeps it for the entries that still carry it.

A **medication day** is a local calendar day with at least one dose of that class. A dose
counts on the day of its own recorded time, read in the zone its entry was logged in; a dose
with no time counts on the entry's start day. Two doses on one day count once, and a day with
two classes counts once under "Any". The card shows the last 30 days (today and the 29 before)
and a bar per calendar month.

**The reference levels are ICHD-3's criteria for medication-overuse headache (8.2),** checked
against [ichd-3.org](https://ichd-3.org/8-headache-attributed-to-a-substance-or-its-withdrawal/8-2-medication-overuse-headache-moh/)
on 2026-10-29:

| ICHD-3 | class | days per month |
|---|---|---|
| 8.2.1 | ergotamine | 10 or more |
| 8.2.2 | triptans | 10 or more |
| 8.2.3 | non-opioid analgesics ("simple pain relievers": paracetamol, NSAIDs, aspirin) | 15 or more |
| 8.2.4 | opioids | 10 or more |
| 8.2.5 | combination analgesics | 10 or more |
| 8.2.6 | two or more of the above, none at its own level | 10 or more in total |

How they are applied, and where that took a decision:

- **Simple pain relievers are one class.** ICHD-3 treats all non-opioid analgesics as a single
  class whose days add up, so paracetamol on some days and ibuprofen on others count together
  toward 15. A product combining only two of them (aspirin with paracetamol, nothing else) is a
  simple pain reliever too, not a combination; "combination" means one with codeine, caffeine,
  butalbital or another adjuvant.
- **The mixed total counts days, not class-days.** 8.2.6 counts days on which any of the classes
  was taken, so a triptan and an NSAID on the same day make one day. It needs at least two of
  the classes in the month: one class under its own level (simple pain relievers on 12 days) is
  not overuse. Combination pain relievers count toward the total; 8.2.6 names ergotamine,
  triptans, non-opioid analgesics and opioids, which is what a combination product is made of.
- **Gepants, ditans, anti-nausea and "other" never raise the notice.** Gepants and ditans postdate
  ICHD-3 and aren't currently thought to cause medication overuse. ICHD-3 also has 8.2.8 for
  "other medication" on 10 or more days, but the class "other" is a catch-all that may hold
  things not taken for the headache itself, so it isn't checked. These are still counted and
  shown.
- **The notice needs 3 months, not a bad 30 days.** ICHD-3 requires regular use for more than 3
  months. The notice appears only when **each of the last 3 complete calendar months** reached a
  level (by any of the rules; a different one each month still counts). The current month never
  counts, and the last-30-days figure is a plain count with no notice attached.
- **It is a count, not a diagnosis.** Medication-overuse headache also requires headache on 15 or
  more days a month and a clinician's judgement. The notice states the counts and the reference
  level, says that it isn't a diagnosis, and suggests discussing it with a doctor. It never says
  to stop or change a medication.

### Preventive medications

Preventives are taken daily and judged over months, so they are recorded once, with start and
stop dates, rather than on each entry. Their start (▲) and stop (▼) months are marked above the
Migraine days per month chart, so a change in the bars can be read against a change in
treatment. The app computes nothing from them; it only shows when they started and stopped.

### What helped

For each medication and each non-drug relief method, the times it was recorded and how many
times "Helped?" was answered yes or no. The share is over the answered tries only: an unknown is
not counted as "didn't help". Names are grouped ignoring case and surrounding spaces. Like the
trigger counts, it is descriptive: it records what you noted, and says nothing about which
treatment works better, which depends on when and how each was taken.

## How Suspected Factors are calculated

**Migraine-days are the days a migraine *started*.** The question here is "what tends to come
before an attack begins?", so the unit of analysis is the day of each attack's **onset**, not
every day you had pain. Logging three entries on one bad day counts once. The **study window**
runs from your first logged migraine to your most recent one.

**Days in the middle of a migraine are left out.** Day 2 onward of a multi-day migraine is
neither an onset day nor a day on which a new attack could have started, so it isn't counted on
either side of the comparison. (If another migraine starts on such a day, that day counts as an
onset as usual.) Without this, a three-day attack would make slow-changing conditions such as
the season, the daylight or a multi-day low-pressure spell look more strongly linked to attacks
than they are, because they are still present on day 3. The Analytics card notes how many days
were left out.

This follows how migraine trigger studies are designed: they look at what precedes the *onset*
of an attack, and treat only headache-free days as days on which a new attack could begin
(see, for example, the individual-patient trigger analysis by Peris et al., *Cephalalgia* 2017,
and weather studies that compare conditions in the hours before onset). It is a deliberate
change from the reference implementation Megrim's analytics were ported from, made in October
2026; with no end times recorded, the results are identical to it.

**Why this number differs from "Migraine days per month".** The two answer different
questions. *Migraine days per month* measures how much migraine you had, so a three-day
migraine counts three days; that is the figure clinicians use to judge frequency and whether a
treatment is working. *Suspected Factors* asks what precedes an attack starting, so the same
migraine counts once, on its first day. Both are right for their purpose.

**The comparison.** For each factor bucket (say, "Friday" or "pressure fell more than 10 hPa"),
Megrim builds a 2×2 table: migraine-days in the bucket, migraine-days outside it,
non-migraine-days in the bucket, non-migraine-days outside it. That requires knowing the bucket
for *every* day in the window, not just migraine days:

- **Calendar factors** (day of week, month, season) are computed exactly — every date has a
  known weekday and season.
- **Moon phase and daylight** are computed astronomically for every day in the window, on the
  device.
- **Pressure change** needs real weather history, so it's only available if you opted into
  weather enrichment. The app fetches a daily-pressure history for your home location from
  Open-Meteo once and caches it, and **both sides of the comparison come from that one series**:
  each day's change in average pressure from the day before, for migraine days and other days
  alike. Days without a pressure value are left out of this table only, and mid-migraine days
  are left out as everywhere else.

  Why one series matters: until October 2026 a migraine day used the pressure change at the hour
  the migraine started, while the other days used daily averages. Hour-by-hour changes swing
  much further than day-to-day averages, so migraine days landed in the extreme buckets far more
  often purely because they were measured differently. That made big drops look strongly linked
  to migraines (an odds ratio of 41 on the sample data, versus about 0.6 when both sides are
  measured the same way). The hourly reading at onset is still kept on each entry and shown in
  the "Pressure change (24h)" chart, which is a plain count. A cache saved by an older version
  has no per-day values, so the pressure factor stays hidden until Analytics next loads online
  and refreshes it.

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

## Check-ins and the tracked-days comparison

A **"No migraine today" check-in** (Log tab, or an empty past day on the History calendar)
records that a day was clear, optionally with the same sleep, stress, triggers and foods an entry
can carry. Without check-ins, a day with no entry could have been clear or simply not logged; with
them, Megrim can tell the two apart. A day with a migraine entry always wins: a check-in on a day
any entry covers is ignored, and saving such an entry removes it.

**Days tracked** (Analytics and the PDF, once you have checked in at least once) counts the days
in the last 30 that have an entry or a check-in, split into migraine days and clear days, and the
same since your first check-in. Days with neither are "not recorded". The more days are tracked,
the more every other figure can be trusted.

**Migraine days vs clear days** compares what you *recorded yourself* on migraine days with what
you recorded on clear days. Suspected Factors can't do this: it compares migraine days with every
day, which works for the weekday or the moon because they are known for every day, but your sleep
or triggers are known only on days you recorded them. So this comparison uses **tracked days
only**:

- **Migraine days** are the days a migraine started, as in Suspected Factors: later days of a
  multi-day migraine are left out, and so is a check-in on any day a migraine covers. When two
  migraines start on one day, the day takes the union of their triggers and foods, the first
  one's sleep, and the higher stress.
- **Clear days** are check-in days.
- **The window starts at your first check-in.** Migraines logged before you started checking in
  have no clear days to be compared with, so they are left out. This differs from Suspected
  Factors, whose window is first to last migraine.
- **Each factor counts only the days it could be read on.** Sleep and stress: the days they were
  recorded. Triggers and foods: the days on which *anything* was recorded (a trigger, a food, sleep
  or stress). A bare one-tap check-in is a tracked day, but it says nothing about triggers;
  counting it as "no triggers" would make every trigger look like a cause.
- **Numbers are bucketed** so they fit a 2×2 table: sleep the night before `< 6 h`, `6–8 h`
  (6 and 8 included), `> 8 h`; stress `1–2`, `3`, `4–5`. Each trigger and each food is its own
  table (recorded that day, or not).
- **The same statistics as Suspected Factors:** a Haldane–Anscombe corrected odds ratio per
  bucket, and a bucket is listed only with at least 3 migraine days in it and an OR above 1.0
  (the strongest 8).
- **It waits for enough data:** at least **30 tracked days, with at least 5 migraine days and 5
  clear days** since your first check-in, and each factor's table needs 5 of each among its own
  days. Until then the card says what is still needed.

**Recall bias is the known weakness of this design.** After a migraine, people look harder for a
cause than they do on a good day, so triggers can be over-recorded on migraine days and look more
linked than they are. Recording the same things on clear days as on migraine days, every time,
is what reduces it. Everything under "What this can and cannot tell you" applies here too, and
more so: the samples are usually smaller.

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
