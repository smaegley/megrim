# Translations: design

_Status: **IN PROGRESS for `v1.0.9`** (phases 1 and 2), branch `feat/translations`, started
2026-11-09. Replaces and
extends backlog #25, which now points here. Decisions D1–D7 were made by Steve on 2026-11-09
([table at the end](#decisions-steve-2026-11-09))._

## As built so far (2026-11-09, branch `feat/translations`)

Phase 1 is done, and phase 2 apart from Weblate (needs Steve's account) and the Chinese font. The
English app looks as before, except as listed under *Visible changes*.

- **619 English messages** in `app/lib/l10n/app_en.arb`, each with a description;
  `[medical]`/`[legal]` marked. Helpers: `context.l10n` (falls back to English where no
  delegate is installed, as in widget tests), `dataLabel()` for stored English values,
  `Formats` for dates/times/numbers, `deviceL10n()` for code with no `BuildContext`.
- **Shipped languages** come from `app/lib/l10n/shipped_locales.dart`, not from the ARB files
  present (otherwise Weblate's unfinished files would ship). `tools/l10n.py sync | check |
  stats | pseudo`; `check` runs in CI.
- **Tests:** the export is identical under any phone language; every default and analytics label
  has a translation; and the **hard-coded text test** runs the store-screenshot flow in the
  `en-XA` pseudo-locale and fails on any English left outside a message (CI generates the
  pseudo-locale first). It also found one layout overflow with longer text (fixed).
- **Notifications** are rebuilt in the new language when the phone's language changes
  (`didChangeLocales`) and at every start, so no "last language" setting was needed.
- **The PDF report** takes the app's `AppLocalizations` (D1).
- **Platform lists:** Android `res/xml/locales_config.xml` + `android:localeConfig`; iOS
  `CFBundleLocalizations`. Both list `en` only for now.

**Visible changes in English** (all from D7, following the phone's locale): dates read the
locale's way ("Mon, Nov 9, 2026" on a US phone, "Mon, 9 Nov 2026" on a British one), times
follow the phone's 12/24-hour setting, counts of 1,000 or more get a separator, the History
calendar starts the week on the region's first day (Monday in Britain), and "across 1 migraine"
is no longer "1 migraines". Store screenshots need retaking at the release.

**Not yet:**
- **Weblate** (Steve, steps below), after the branch is merged to `main`.
- **Chinese PDF font (D3):** Noto Sans SC is about 8 MB as OTF, but the `pdf` package needs
  TrueType, and the TrueType build is a 17.7 MB variable font. Proposal: add the font and the
  report's font fallback when Simplified Chinese is close to the bar, not in 1.0.9, so the app
  doesn't grow by 10–18 MB for a language that isn't offered yet.
- **iOS `InfoPlist.strings`** (the purpose strings and the shortcut title in other languages)
  needs the Xcode project on the Mac; only matters once a second language ships.
- **Place names** from the geocoder are requested in English (`language: 'en'`); changing that
  changes a network request, so it's left for a language that needs it.

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
| **1. Extract** | All text into `app_en.arb`; data labels mapped for display; dates and numbers follow the locale | English dates follow the locale (D7) | **`v1.0.9`** |
| **2. Translation pipeline** | Weblate, CI checks, PDF fonts, report language, platform language lists | None until a language is complete | **`v1.0.9`** |
| **3. First languages** | Each language ships once it meets the bar (D5) | New languages | Later releases, per language |
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
  widget tree, so it takes an `AppLocalizations` passed in, not `BuildContext`.
- **`legal.dart`**: the disclaimer and the About text. See
  [Medical and legal wording](#medical-and-legal-wording).
- **Notifications** (`notifications.dart`): "How was today?", "Migraine in progress", and the
  action buttons (*No migraine today*, *Log*, *End*). Notifications are scheduled ahead with their
  text baked in, so the app **reschedules them when the language changes** (as built: at every
  start, and on `didChangeLocales`).
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
    "Mon 9 Nov 2026". Decided: follow the locale (**D7**).
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
  Decided: suggestions only (**D4**).
- **Glossary** in Weblate for the terms that must stay consistent: migraine, aura, attack,
  postdrome (#30), preventive, relief, check-in, "Migraine days", "clear day". Translators see it
  next to every string.
- A short `docs/TRANSLATING.md` for volunteers: the Weblate link, the glossary, what "community
  translation" means, how medical strings are handled, and how to request a new language.

### Weblate setup (Steve, once)

Needs your GitHub account, so it isn't scripted. Do it after the branch with phase 1 is merged to
`main` (Weblate reads `main`).

1. Sign in at <https://hosted.weblate.org> with GitHub, and **request libre hosting** for a new
   project "Megrim" (the form asks for the repo URL and the licence, GPL-3.0). Approval is
   manual and can take a few days.
2. Add a **component** "App":
   - Source code repository `https://github.com/smaegley/megrim.git`, branch `main`.
   - Version control: **GitHub pull request** (Weblate pushes to its fork and opens PRs; it
     never pushes to `main`). Authorise the Weblate GitHub app when asked.
   - File format **ARB file**; file mask `app/lib/l10n/app_*.arb`; monolingual base language
     file and template for new translations both `app/lib/l10n/app_en.arb`.
   - Language code style: **underscore** (`zh_Hans`), so files come out as
     `app_zh_Hans.arb`, which gen-l10n expects.
3. Project settings:
   - **Reviews: on.** `[medical]` and `[legal]` messages need a second person (D4/D5).
     Weblate shows each message's description as its explanation.
   - **Machine translation:** enable a free service for *suggestions*. Don't turn on automatic
     translation (D4).
   - **Glossary:** add migraine, aura, attack, prodrome, postdrome, preventive, relief,
     check-in, migraine day, clear day, impact, Megrim (not translated).
   - Contributor agreement: none needed (GPL-3.0, contributions under the same licence).
4. Mark `appTitle` ("Megrim") read-only in Weblate.
5. Start the languages people asked for: Ukrainian (the volunteer on #22), French, Simplified
   Chinese (`zh_Hans`). Post the Weblate link on #22 and #19.

Then, per release: `tools/l10n.py stats` shows each language's coverage; when one meets the bar,
add it to `app/lib/l10n/shipped_locales.dart`, run `tools/l10n.py sync`, and test it on a phone.

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
  use besides opt-in weather, so downloading the font later isn't an option. Decided: **Regular only** (D3).
- Use it as a **fallback font** (the `pdf` package's `fontFallback`), so mixed text works:
  Chinese labels with Latin numbers, or a Chinese user's notes with English medication names.
- On screen, CJK text uses the phone's system font and needs nothing.

### Report language

**The report uses the app's language (D1).** A French phone produces a French report, which is
the #22 case. There's no separate report-language choice. Internally the report still takes an
`AppLocalizations` passed in, not `BuildContext`, so a choice could be added later without
rework.

### Choosing the app's language

Android 13+ and iOS both offer a per-app language in the system settings. Both need the app to
declare its languages:

- Android: `res/xml/locales_config.xml` and `android:localeConfig` in the manifest.
- iOS: `CFBundleLocalizations` in `Info.plist`.

Both lists, and the app's own `supportedLocales`, come from **`app/lib/l10n/shipped_locales.dart`**
(`kShippedLocales`), not from the ARB files present: gen-l10n lists every ARB it finds, and
Weblate commits unfinished translations as they progress. `tools/l10n.py sync` writes the
platform lists; `tools/l10n.py check` (CI) fails if they're out of step or a shipped language is
below the bar. There's no in-app picker (D2).

**When the phone's language isn't supported, the app is in English.** Flutter compares each
language on the phone's preferred list, in order, with the app's supported languages and uses the
first match. If nothing matches, it uses the **first** entry in `supportedLocales`, so `en` must
stay first (gen-l10n puts the template language first). Examples:

- Phone in German, app has no German: English.
- Phone set to German, then French as second choice, app has French: French.
- The system per-app language screens only list the languages the app declares, so a user can't
  pick an unsupported one there.
- Material's own text (date pickers, "OK", "Cancel") follows the same resolved language, so a
  screen never mixes English app text with German buttons.
- **Chinese variants:** with only `zh` (Simplified) supported, a phone set to Traditional
  Chinese (Taiwan, Hong Kong) matches on the language code and gets Simplified Chinese, not
  English. That's usually the more readable fallback, but declare the locale as
  `zh_Hans` and decide deliberately when Simplified Chinese ships: keep that behaviour, or send
  Traditional users to English until a `zh_Hant` translation exists.

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

## Decisions (Steve, 2026-11-09)

| | Question | Decided |
|---|---|---|
| **D1** | Report language: follow the app, or let the user choose when exporting? | **Follow the app.** No export-time choice |
| **D2** | App language: system settings only, or also an in-app picker? | **The phone's settings only** (Android 13+ and iOS per-app language; older Android follows the phone's language). No in-app picker. Unsupported languages fall back to English: see [Choosing the app's language](#choosing-the-apps-language) |
| **D3** | Chinese PDF font | **Noto Sans SC Regular only.** Measure the size first; bold headings in Chinese use size instead of weight |
| **D4** | Machine translation in Weblate | **Suggestions only.** A person saves every string, and `[medical]`/`[legal]` ones need a second person |
| **D5** | The bar for shipping a language | **100% of the report, notifications and `[medical]`/`[legal]` strings reviewed, and at least 90% of everything else** |
| **D6** | Which release | **Phases 1 and 2 ship in `v1.0.9`** (still English only). Each language then ships in a later release once it meets D5. Phase 1 starts before #30/#31 |
| **D7** | English dates | **Follow the phone's locale** (US: "Mon, Nov 9, 2026"). Store screenshots change slightly |
