# App Store release prep (iOS)

Everything decided/drafted in advance so the release is execution-only once the Apple Developer
membership (enrolled 2026-09-03, individual, steve@maegley.com Apple ID) is approved.

## One-time setup order (after approval email)

1. **appstoreconnect.apple.com** → sign in → accept the developer agreements (Agreements, Tax,
   and Banking; the paid-apps agreement is NOT needed — free app, no IAP).
2. **Xcode → Settings → Accounts** → add the Apple ID → the team ("Steve Maegley") appears.
3. **App Store Connect → Apps → "+" → New App**: platform iOS, name **Megrim**, primary language
   English (U.S.), bundle ID `org.maegley.megrim` (register it when prompted), SKU `megrim`.
4. In Xcode, Runner target → Signing & Capabilities → team = Steve Maegley, automatic signing.
5. Product → Archive → Distribute → App Store Connect. Export-compliance question is already
   answered by `ITSAppUsesNonExemptEncryption=false` in Info.plist.

## Listing content (draft — paste into App Store Connect)

- **Name** (30 chars max): `Megrim: Migraine Diary` — plain "Megrim" is already taken on the
  App Store (name is globally unique per store; discovered at app creation, 2026-09-03). The
  home-screen name stays "Megrim" via CFBundleDisplayName; only the listing carries the long form.
- **Subtitle** (30 chars max): `Private, offline, open source` (the name now says what it is, so
  the subtitle carries the differentiators instead)
- **Category**: Primary **Health & Fitness**, Secondary **Medical**
- **Privacy policy URL**: `https://github.com/smaegley/megrim/blob/main/docs/PRIVACY.md`
- **Support URL**: `https://github.com/smaegley/megrim`
- **Keywords** (100 chars max, comma-separated; "migraine"/"diary" omitted — words already in
  the name are indexed, duplicating them wastes characters):
  `headache,tracker,log,trigger,aura,barometric,pressure,weather,private,offline,journal,health`
- **Age rating questionnaire**: everything "None" except **Medical/Treatment Information →
  Infrequent/Mild** (the app records medications taken). Expect a 12+ rating from that answer.
- **Description**: reuse `fastlane/metadata/android/en-US/full_description.txt` nearly verbatim —
  it already leads with the privacy story and carries the NOT-a-medical-device disclaimer that
  App Review looks for on health apps. Change only: drop the `*` bullet markers for `•` (the App
  Store renders plain text), and s/on your phone/on your device/.
- **Promotional text** (170 chars, editable without review):
  `An open-source migraine diary that finds your patterns — weather, pressure, moon, season —
  entirely on your device. No accounts. No cloud. No tracking.`

## App Privacy ("nutrition label")

**Data Not Collected** — the honest answer across the board: no data leaves the device to the
developer (there is no server). The Open-Meteo weather fetch is the app acting on the user's
behalf, opt-in, with a ~1 km-rounded location and no identifiers; it is not developer collection.
Answer "No" to all collection questions; the label renders as "Data Not Collected".

## Availability + the Ko-fi decision

**Decision needed from Steve at submission time:**

- **Option A — US storefront only, keep the Ko-fi tile.** Post-Epic (guideline 3.1.1, May 2025)
  external donation links are allowed on the US storefront with no entitlement or fee. Expansion
  to more countries later is a settings change in App Store Connect, but the same binary serves
  every storefront — so expanding later means first shipping an update that removes/gates the
  Ko-fi tile.
- **Option B — worldwide, remove the Ko-fi tile from the iOS build** (compile-time flag or
  platform check). Donations then live only on GitHub/F-Droid/website.

Recommendation: **A** for v1 — it matches the reason the App Store was chosen over Play, and the
audience loss (non-US) can be revisited with real numbers.

## Screenshots

Device families: the project currently targets iPhone **and iPad** (Xcode default). Keeping iPad
costs one extra screenshot set; the layouts are responsive ListViews and the share-sheet popover
anchor is already handled. Keep iPad unless review friction appears.

Required sets (simulator screenshots are acceptable; take with real-looking demo data —
`megrim-sample-data.json` imported, dark mode for brand consistency, some light-mode variety):

- iPhone 6.9" (e.g. iPhone 17 Pro Max simulator)
- iPad 13" (e.g. iPad Pro 13" simulator) — only if iPad support kept

Suggested shots (same set both sizes): Quick Log idle, History calendar with a multi-day
connector visible, Analytics dashboard (stat tiles + factors), Analytics donuts, Event Detail
with enrichment, Settings/export.

## Review notes (App Review information box)

- No account, no login — the app is fully usable from first launch; onboarding asks only for an
  optional home location.
- Health disclaimer is in-app (About) and in the description: personal diary, not a medical
  device, no diagnosis/treatment claims.
- Weather enrichment is opt-in; sole network endpoint is api.open-meteo.com (documented in
  docs/PRIVACY.md).
- The statistical methodology behind "Suspected Factors" is publicly documented in plain
  language: https://github.com/smaegley/megrim/blob/main/docs/METHODS.md (retrospective
  descriptive statistics only — no diagnosis, no prediction).

## Post-approval loose ends

- README.md line 12 still says "migraine diary for Android" — update once the iOS release is
  live, along with a store badge/link section.
- Release automation (macOS runner building a signed IPA in CI) is deliberately deferred —
  first submissions go through Xcode by hand.
