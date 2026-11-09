# Translations: design

_Status: **PROPOSED**, 2026-11-09. Nothing built yet. Replaces and extends backlog #25, which
now points here. Decisions marked **D1–D7** are Steve's to make before the phase they block._

## Why

Three requests are open on GitHub, all tracked under #22 (`localization`, `planned`):

- #19: Simplified Chinese (zh-CN). The requester's English is limited.
- #22: "other languages", especially the **PDF report**: the reporter wanted a French report for
  their neurologist. It suggests **Weblate** so the community can translate.
- A commenter on #22 offered to translate into Ukrainian themselves.

Today Megrim has no localization setup at all. There is no `flutter_localizations` and no
`l10n.yaml`, and roughly **550–600 English strings are hard-coded** across about 30 files under
`app/lib/` (backlog #25 counted ~360 in October; 1.0.8 added symptoms, impact, medications and
check-ins). Most are in `analytics_screen.dart` (~78), `settings_screen.dart` (~59),
`event_detail_screen.dart` (~48), `report_content.dart` (~45) and `report_pdf.dart` (~40).

## Goals and non-goals

**Goals**

- Any language can be added by dropping in one translation file, without code changes.
- The PDF report is translated too. It's the part the requesters care most about.
- Volunteers can translate in a browser (Weblate), without touching Git or Dart.
- Everything stays offline. No network call is added for translations or fonts.

**Non-goals (for now)**

- Right-to-left languages (Arabic, Hebrew). Nobody has asked, and RTL needs a layout pass of its
  own. Where it costs nothing, new code uses direction-neutral widgets (`EdgeInsetsDirectional`,
  `start`/`end`) so it doesn't get harder later.
- Translating the docs on GitHub (README, METHODS, PRIVACY, IMPORT). They stay English.
- Changing the JSON or CSV export. **The export format must not change** in any language (see
  [Data stays English](#data-stays-english-translate-only-for-display)).
- Translating text the user typed (their own triggers, symptoms, notes).

## Phases

| Phase | What | Visible change | Can ship on its own |
|---|---|---|---|
| **1. Extract** | All text into `app_en.arb`; data labels mapped for display; dates and numbers follow the locale | None in English | Yes: any release |
| **2. Translation pipeline** | Weblate, CI checks, PDF fonts, report language, platform language lists | None until a language is complete | Yes |
| **3. First languages** | Each language ships once it meets the bar (D5) | New languages | Per language |
| **4. Store listings** | F-Droid listing via Weblate; App Store localizations by hand | Store pages | Optional |

Phase 1 is the big, dull one and needs a dedicated block of time. It touches nearly every screen.
Phases 2–3 are mostly setup and waiting for translators.

---

## Phase 1: extract the text

### Setup

- `pubspec.yaml`: add `flutter_localizations` (SDK) and `flutter: generate: true`. `intl` is
  already a dependency (`^0.19.0`). Check that its version matches what the Flutter SDK pins.
- `app/l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`,
  `output-localization-file: app_localizations.dart`, `nullable-getter: false`. Generated code goes
  in the build directory, not the repo (the Flutter default).
- `MaterialApp` gets `localizationsDelegates: AppLocalizations.localizationsDelegates` and
  `supportedLocales: AppLocalizations.supportedLocales`. Material's own widgets (date pickers,
  "OK"/"Cancel", the time picker) then come translated for free.
- A small `context.l10n` extension for brevity, in the style of the existing helpers.

### What gets extracted

- **Every user-visible string in `app/lib/`**: screens, widgets, dialogs, snack bars, tooltips,
  semantics labels (TalkBack and VoiceOver read them too), empty states, error messages.
- **The PDF report**: `report_content.dart` and `report_pdf.dart`. The report is built outside the
  widget tree, so it takes an `AppLocalizations` passed in, not `BuildContext` (needed for D1).
- **`legal.dart`**: the disclaimer and the About text. See
  [Medical and legal wording](#medical-and-legal-wording).
- **Notifications** (`notifications.dart`): "How was today?", "Migraine in progress", and the
  action buttons (*No migraine today*, *Log*, *End*). Notifications are scheduled ahead with their
  text baked in, so the app **reschedules them at startup when the language has changed** (store
  the language used last time in `app_settings`).
- **Native strings outside Dart**:
  - Android: `res/values/strings.xml` (the "Log migraine" shortcut). Translations go in
    `values-<lang>/strings.xml`.
  - iOS: `Info.plist` strings (the shortcut title, `NSFaceIDUsageDescription` and the other
    purpose strings). Translations go in `<lang>.lproj/InfoPlist.strings`.
  - These are few. Phase 1 only sets up the English files in a translatable layout. Weblate can
    handle Android XML and `.strings` as extra components in phase 2.

**Not extracted:** log messages, exception text that never reaches the screen, export keys and
values, test strings.

### How messages are written

- **One whole sentence per message.** No gluing fragments together: word order differs between
  languages. `'Last 30 days, including $n without headache'` becomes one message with a
  placeholder, not two strings joined.
- **ICU plurals** for counts: `{count, plural, =1{1 day} other{{count} days}}`. Slavic languages
  (Ukrainian) have more plural forms than English, and ICU handles that if the message is written
  this way.
- **ICU `select`** where a label depends on a value (impact level, headache yes/no/unsure).
- **A description (`@key.description`) on every message.** Weblate shows it to translators as
  context. Short labels like "Normal", "Reduced" or "Unable" can't be translated well without
  knowing what they describe.
- **Key names** describe the meaning, grouped by screen: `settingsDonateTitle`,
  `eventImpactUnable`, `reportSummaryMigraineDays`. Not the English text, which would change.

### Data stays English, translate only for display

This is the main trap (already noted in #25), and 1.0.8 made it bigger.

The **default vocabulary** (`kDefaultTriggers`, `kDefaultHeadLocations`, `kDefaultSymptoms`,
`kDefaultRelief` in `database.dart`, plus "Travel") is seeded into the database as English
strings. Those strings are saved in entries, compared as keys in Analytics, and written to the
export. The same goes for the **factor labels**: seasons, moon phases, day of week (`kDowLabels`
in `correlations.dart`), time-of-day buckets, impact levels, and factor names like
`'Pressure Δ 24h (hPa)'`, which `report_content.dart` uses as a lookup key.

Rule: **the stored value stays the English string, and the app translates it at display time.**

- One mapping function per kind (`displayVocab(kind, value, l10n)`, `displayFactor(...)`). It
  returns the translation when the value is a known default, and otherwise returns the value
  unchanged (anything the user typed).
- Manage screens show the translated name for defaults. **Renaming a default** stores the new
  text as the user's own (it is then shown exactly as typed in every language). That's already how
  a rename behaves today.
- Analytics groups by the stored value, so counts don't depend on the language. Switching the
  phone's language never splits "Nausea" and "Nausée" into two rows.
- The export stays English (`symptoms: ["Nausea"]`), so files move between phones in different
  languages and the import format doesn't change.
- Known edge: a user who typed their own "Nausée" *and* has the default "Nausea" sees two
  similar chips. That's rare and harmless. Leave it.

### Dates and numbers

- About 25 `DateFormat('…')` calls hard-code the field order (`'EEE d MMM yyyy, HH:mm'`). Switch
  them to locale-aware forms (`DateFormat.yMMMEd(locale)`, `DateFormat.Hm(locale)` and the like),
  in one shared helper so screens and the report agree.
  - English output changes slightly. US English would show "Mon, Nov 9, 2026" instead of today's
    "Mon 9 Nov 2026". Decide in **D7**.
  - 12- vs 24-hour time can follow the phone (`MediaQuery.alwaysUse24HourFormat`) on screen. The
    PDF uses the locale's default.
- **Numbers** go through `NumberFormat` (French writes `7,5 h`). There are about 10
  `toStringAsFixed` calls to replace.
- **Bug that translation exposes:** the sleep-hours fields parse with `double.tryParse`
  (`event_detail_screen.dart:246`, `checkin_screen.dart:63`), so a user typing `7,5` gets nothing
  saved. That's already wrong for any European user on the iOS decimal keypad. Accept both `.` and
  `,`. Fix it in phase 1, or earlier as a small bug fix.
- The History calendar already starts the week on the locale's first day
  (`history_screen.dart:560`). Nothing to do there.

### Tests

- About 25 test files use `find.text('…')` against English. A shared test wrapper sets up the
  delegates and an `en` locale, so the assertions stay as they are.
- **Export is never localized:** export the sample data under `en` and `fr`, then check the files
  are identical apart from timestamps.
- **Every default vocabulary value and factor label has a translation key:** this test fails
  when someone adds a default but forgets the mapping.
- **Pseudo-locale run** (a throwaway `app_xx.arb` with every string wrapped and lengthened about
  40%, e.g. `⟦Ŝéţţîñĝš·····⟧`): a manual pass on a phone shows any string still hard-coded, plus
  layouts that break when French or German text runs ~30% longer. Not shipped.
- The store-screenshot flow (`test/screenshot_flow_test.dart`) should produce the same shots,
  except where D7 changes date formats on purpose.
- PDF: generate the sample report before and after, and compare.

### Done when

The app looks and behaves the same in English (apart from D7), `flutter analyze` is clean, all
tests pass, the export is identical, and the pseudo-locale pass finds no hard-coded text.

---

## Phase 2: the translation pipeline

### Weblate

- Apply for **Hosted Weblate's free plan for open-source projects** (Megrim qualifies: public
  repo, GPL-3.0). Check the current conditions when applying.
- Components:
  1. **App** (`app/lib/l10n/app_*.arb`, format "ARB file", template `app_en.arb`).
  2. Later, **Android strings** and **iOS InfoPlist.strings** (a handful of strings each).
  3. Phase 4: **F-Droid listing** (`fastlane/metadata/android/<locale>/`).
- Weblate commits translations and opens a **pull request** on GitHub. Steve (or I) reviews and
  merges like any other PR, and CI runs on it. Weblate doesn't push to `main` directly.
- Weblate offers machine-translation suggestions. Whether they can be saved as translations is
  **D4**.
- **Glossary** in Weblate for the terms that must stay consistent: migraine, aura, attack,
  postdrome (#30), preventive, relief, check-in, "Migraine days", "clear day". Translators see it
  next to every string.
- A short `docs/TRANSLATING.md` for volunteers: the Weblate link, the glossary, what "community
  translation" means, how medical strings are handled, and how to request a new language.

### CI checks (on every PR, including Weblate's)

- `flutter gen-l10n` succeeds (catches broken ICU syntax and placeholder mismatches).
- No ARB has keys the English template doesn't have.
- The report's font covers every character the language uses (next section). This check is
  what would have caught Chinese printing as boxes.

### PDF fonts

The report embeds `NotoSans-Regular/Bold.ttf` (1.3 MB, Latin/Greek/Cyrillic), because the PDF's
built-in fonts are Latin-1 only.

- **French, Ukrainian, and most European languages: nothing to do.** Noto Sans already covers
  them.
- **Chinese (zh-CN) needs a CJK font:** Noto Sans SC. It's large: several MB per weight, roughly
  10 MB or more for Regular and Bold together (measure before deciding). The app has no network
  use besides opt-in weather, so downloading the font later isn't an option. **D3.**
- Use it as a **fallback font** (the `pdf` package's `fontFallback`), so mixed text works:
  Chinese labels with Latin numbers, or a Chinese user's notes with English medication names.
- On screen, CJK text uses the phone's system font and needs nothing.

### Report language

The patient's phone and the doctor may not share a language (the #22 reporter is the reverse
case: a French phone wanting a French report, which the default covers). **D1.**

### Choosing the app's language

Android 13+ and iOS both offer a per-app language in the system settings. Both need the app to
declare its languages:

- Android: `res/xml/locales_config.xml` and `android:localeConfig` in the manifest.
- iOS: `CFBundleLocalizations` in `Info.plist`.

Generate both lists from the ARB files that meet the bar, with a small script run in CI, so they
can't drift. Whether to also add an in-app picker is **D2**.

### Credits

About lists each language's translators, by the name they choose in Weblate (or "community
translation"), and links to `TRANSLATING.md`.

---

## Phase 3: shipping a language

- A language is **included in a release** when it meets the bar in **D5**. Below the bar it stays
  in Weblate and doesn't appear in `supportedLocales`, so nobody gets half an app.
- Missing strings fall back to English (gen-l10n's behaviour). Translations will always lag a
  little behind new features. That's expected; the bar is checked at each release.
- **Release checklist** gets: "freeze strings for N days before the tag, so translators can
  catch up" (N = 3–5), and "check each shipped language still meets the bar".
- Likely first wave, depending on volunteers: **Ukrainian** (volunteer on #22), **French** (the
  #22 reporter may help; ask them), **Simplified Chinese** (#19; needs a reviewer, and D3).

## Phase 4: store listings

- **F-Droid:** the `fastlane/metadata/android/` files (short and full description, changelogs)
  can be a Weblate component. F-Droid shows them by language automatically.
- **App Store:** localizations are added by hand in App Store Connect (name, subtitle, keywords,
  description). Screenshots can stay English. This ties in with the region expansion planned in
  `STATUS.md`: a translated listing matters more once the app is in those countries.
- Optional. Do it once a language has shipped in the app.

---

## Medical and legal wording

- The disclaimer ("a personal diary, not a medical device"), the medication-overuse notice
  (ICHD-3 wording, approved by Steve 2026-10-29), symptom names and the METHODS-based wording on
  Analytics are where a loose translation does real harm.
- Mark these messages in their ARB descriptions with `[medical]` or `[legal]`. In Weblate they get
  the "needs review" state, and a second translator, or someone with medical knowledge if
  available, approves them before a language ships.
- About says translations are community-made and **the English text is the version that counts**
  for the disclaimer and privacy wording.
- The PDF footer keeps "Megrim is a personal diary, not a medical device", translated, in every
  language.

---

## Decisions for Steve

| | Question | Recommendation | Blocks |
|---|---|---|---|
| **D1** | Report language: follow the app, or let the user choose when exporting? | **Follow the app, plus a "Report language" choice in the export sheet** (defaults to the app's language). It's cheap once the report takes an `AppLocalizations`, and it covers a patient seeing a doctor in another language | Phase 2 |
| **D2** | App language: system settings only, or also an in-app picker? | **System settings only** for now (Android 13+ and iOS both offer it). Older Android follows the phone's language. Add a picker only if people ask | Phase 2 |
| **D3** | Chinese PDF font: bundle Noto Sans SC (about +10 MB to the app), Regular only (smaller, no bold in Chinese), or no Chinese report yet? | **Regular only** to start: measure the size first; bold headings in Chinese can use size instead of weight | zh-CN ships |
| **D4** | Machine translation in Weblate: allowed as suggestions only, or saved as translations? | **Suggestions only**: a person saves every string, and `[medical]`/`[legal]` ones need a second person | Phase 2 |
| **D5** | The bar for shipping a language | **100% of the report, notifications and `[medical]`/`[legal]` strings reviewed, and at least 90% of everything else** | Phase 3 |
| **D6** | Where phase 1 goes, relative to #29, #28, C2 (1.1.0) and #30/#31 | Phase 1 has no visible change, so it can go into whichever release is next. Start it before #30/#31, so those features are written with translatable text from day one | Start of work |
| **D7** | English dates: keep today's fixed "Mon 9 Nov 2026" everywhere, or follow the locale (US: "Mon, Nov 9, 2026")? | **Follow the locale.** That's what users expect, and it's the same code path every other language uses. It changes the store screenshots slightly | Phase 1 |
