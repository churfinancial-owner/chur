# Localization Reference

How Chur's multi-language support is built, what's done, what's left, and the
patterns to follow when migrating the rest. Read this before touching UI
strings or locale-resolution logic. **Update it whenever the architecture,
progress, or a new gotcha changes.**

Merged to `main` 2026-08-02 (the working branch, `claude/app-localization-setup-mzadsw`,
was deleted after the fast-forward merge — don't look for it). Original plan
lived in `/root/.claude/plans/look-at-the-latest-cosmic-hejlsberg.md` (Phase
1-3 engineering foundation) and the fuller roadmap discussed in chat (Phase 4
= UI string migration, Phase 5 = benefit-JSON translation content, Phase 6 =
Cards/Merchants proper nouns deferred, Phase 7 = docs).

**Note on tooling availability**: earlier notes in this doc say things like
"no Xcode/xcodebuild in this container" — that was true for the sessions that
wrote those notes, but is **not a fixed constraint of this environment**. A
later session confirmed `xcodebuild`, `xcrun simctl`, and a real `swift`
interpreter are all available and were used extensively (building for
`iphonesimulator`, installing/launching on a booted simulator, seeding
SwiftData/UserDefaults directly via `sqlite3`/`simctl spawn defaults` to reach
otherwise-hard-to-navigate app states, and computing exact String Catalog keys
by evaluating `LocalizedStringResource` in a standalone `swift` script). Check
current tool access yourself rather than trusting old "not available" notes.

## Architecture (shipped)

- **`Chur/Core/Localization/AppLocale.swift`** — the single seam for locale
  resolution. `AppLanguage` enum (`.system`, `.english`, `.chineseHK`) maps to
  a `Locale`. `AppLocale.localePriorityKeys(for:)` is the shared fallback
  chain (`["zh-Hant-HK", "zh-Hant", "zh", "en"]` etc.) used by both UI
  strings and model-content lookups — **never branch on `Locale.current`
  directly in new code**, always go through this file.
- **`User.languagePreference`** (`ChurSchemaV1_14`) — the syncable source of
  truth for a user's explicit language override (`"system"` default). Mirrored
  to `UserDefaults["appLanguage"]` (read via `AppLocale.activeLanguage`) so
  `ChurApp.swift` can resolve the active language synchronously via
  `@AppStorage` before a `ModelContext` exists. `LanguageSettingsView.swift`
  (Settings → Language) writes both.
- **`Chur/Resources/Localizable.xcstrings`** — the String Catalog. One flat
  `key → {locale: translation}` map. `en` is the source language (the key
  itself doubles as the English text unless a literal differs from its
  key). Currently only `zh-Hant-HK` has translations populated.
- **Project config**: `zh-Hant-HK` registered in `Chur.xcodeproj/project.pbxproj`
  (`knownRegions`) and `Chur/Info.plist` (`CFBundleLocalizations`).
- **`Benefit.localized` / `SpendingCategory.name*` / `Badge.displayName`**
  (model-content localization) all resolve through `AppLocale` instead of
  independently branching on `Locale.current` — see
  `Benefit_LocalizedStrings.swift` / `SpendingCategory.swift` / `Badge.swift`.
  **`Badge.swift` was missed in the original Phase 2 pass** (only Benefit
  and SpendingCategory were migrated at the time — Badge wasn't yet
  identified as in-scope) and kept reading `Locale.current` directly until
  caught later; see "Known-fixed bugs" below. **When migrating a new
  feature, always check its `DataModel`/model files for `Locale.current`
  usage, not just its View files** — a feature's data layer is easy to
  overlook since it doesn't show up in a grep for `Text(`/`Label(` etc.
- **Audited (this session): every remaining `Locale.current` reference
  in the codebase is for `.region`** (currency/country detection in
  `RegionDatabase`, `EarningRatesSection`, `EarningPowerTabViewModel`,
  `ParentCategoryPopup`) — a legitimately separate, independently
  user-configurable axis (Region & Currency setting vs. Language
  setting), not a language-resolution bug. No other Badge-style misses
  found as of `b36adf4`.

## How a string gets migrated (the recipe)

1. **Plain literal** — `Text("Some Label")`, `Button("Cancel")`,
   `.navigationTitle("Settings")`, `Label("X", systemImage:)`,
   `TextField("placeholder", text:)`, `Toggle("X", isOn:)`, `Section("X")`,
   `.alert("Title", ...)` — all resolve through `LocalizedStringKey`
   automatically. **No code change needed.** Just add the key + `zh-Hant-HK`
   translation to `Localizable.xcstrings`.
2. **Verbatim `Text(String)` gotcha** — if the string passes through a
   variable, computed property, `@State`, or a custom view's `String`
   parameter before reaching `Text(...)`, SwiftUI uses the *verbatim*
   `Text(StringProtocol)` initializer, which does **not** look up the
   catalog. Fix: wrap the literal in `AppLocale.string("...")` at the
   point it's first assigned/passed — not at the `Text()` call site.
   **Always use `AppLocale.string(...)` for this pattern — never
   `String(localized: "...")` (bare) or `String(localized: "...",
   locale: AppLocale.current)`.**
   - Bare `String(localized: "...")` defaults its `locale:` parameter
     to `Locale.current` (the device's *system* language) and does
     **not** participate in SwiftUI's `.environment(\.locale, ...)` the
     way a literal `Text("...")` does. A first pass of this migration
     used the bare form everywhere, which quietly ignored the in-app
     Language override for every one of those ~170 call sites (they'd
     only look translated if the device's system language happened to
     already match) — caught only once Xcode's real build flagged the
     mismatch.
   - `String(localized: "...", locale: AppLocale.current)` (explicit
     locale, no `bundle:`) was the fix applied for the above — but
     turned out to have its **own** bug, confirmed on-device (2026-08-02,
     real `xcodebuild`/simulator run, not just code reading): passing an
     explicit `locale:` to `String(localized:)` silently falls back to
     the source-language (English) string instead of resolving the
     matching `.lproj` bundle, even though the exact same key/locale
     combination resolves correctly via `Bundle(path:).localizedString(forKey:)`
     or via `LocalizedStringResource(key, locale:, bundle: .atURL(...))`.
     Root-caused with a standalone `swift` script loading the built
     `.app` bundle directly (see repro below) — ruled out project/catalog
     config in the process.
   - **Current fix, use for all new code:** `AppLocale.string(_:table:comment:)`
     in `AppLocale.swift`, which wraps `LocalizedStringResource(key,
     table:, locale: current, bundle: .atURL(Bundle.main.bundleURL))` —
     this does **not** have the bug. Fixed project-wide (mechanical
     `String(localized: "X", locale: AppLocale.current)` →
     `AppLocale.string("X")` across all ~45 files) and verified on-device
     that previously-broken strings ("Your %lld" wave divider, "Annual
     Fees"/"Cards"/"Redeemed" stat labels, "Good Afternoon" greeting) now
     render in `zh-Hant-HK`. Keep using `AppLocale.string(...)` for every
     future occurrence of this pattern — do not reintroduce
     `String(localized:locale:)`.
   - Repro, if this needs re-investigating on a newer Swift/Xcode version
     (run from a machine with Xcode, after `xcodebuild ... build` for
     `iphonesimulator`):
     ```swift
     let bundle = Bundle(path: "/path/to/Chur.app")!
     let locale = Locale(identifier: "zh-Hant-HK")
     String(localized: "Good Afternoon", bundle: bundle, locale: locale) // BUGGY: returns "Good Afternoon"
     String(localized: LocalizedStringResource("Good Afternoon", locale: locale, bundle: .atURL(bundle.bundleURL))) // correct: "午安"
     ```
   Hit so far: computed properties returning conditional strings
   (`footerText`, `greeting`, `lastSyncedAtText`, `headerSubtitle`,
   `rewardPlanDisplay`, `boostDisplay`), custom component params
   (`RatePill`/`BankPill`/`DetailRow`/`CardSectionHeader`/
   `EmptyStatePlaceholder`/`ProgramValueRow`'s `label`/`title`/`text`
   fields), and `@State private var xError: String?` assigned from
   multiple branches then shown via `Text(error)`.
3. **Same literal is both display text AND a business-logic/identifier
   value** — e.g. an enum's `rawValue` used for persistence or equality
   checks, or a filter option array compared elsewhere against raw card
   data. Do **not** translate the identifier. Add a separate `displayName`
   computed property (switch over cases, `String(localized:)` per case)
   and use that for display instead. Done for: `NotePreset.displayName`,
   `GoToCardSheet.SearchSection.displayName`,
   `CardInfoContentView_CardInformationSection.cardTypeDisplayLabel(for:)`,
   `FinancialStrategy.displayName`/`.tagline`. `networkOptionLabel` (Visa,
   Mastercard, etc.) was deliberately left alone — proper nouns.
4. **Interpolated `Text("... \(x) ...")` / alert messages** — for a
   *single*-argument interpolation, it's safe to hand-write: wrap in
   `String(localized: "Text \(x) more text", locale: AppLocale.current)`
   and add the resulting key (Swift converts `\(x)` to `%@`/`%lld`/etc.
   automatically — e.g. `"Your \(selectedYear)"` → catalog key
   `"Your %lld"`). For *multi*-argument interpolations, the catalog needs
   positional specifiers (`%1$@`, `%2$@`, ...) that are easy to get wrong
   by hand-guessing — but you don't have to guess: write a throwaway
   `swift` script that evaluates `LocalizedStringResource("your \(a) and
   \(b) string")` and prints its `.key` (see the repro snippet a few
   paragraphs up for the exact pattern) to get the *exact* key Xcode
   would generate, then hand-write the translation against that
   confirmed key. Most single- and multi-argument strings from the
   original migration pass were filled in after Pak Ho's local Xcode
   build re-extracted the whole project correctly (see Progress) — only
   a few Debug-only/News ones remain unfilled by design.
5. **Pluralized counts** ("1 card" vs "N cards", "N benefit(s)", "N day(s)")
   — Chinese has no plural forms, so a single non-inflected translation
   covers every count; you do **not** need Xcode's stringsdict plural-variation
   UI for this app's one target language. Two working patterns, pick based
   on where the string lives:
   - **Inside a literal `Text("...")` call** — use Apple's markdown
     auto-inflection: `Text("^[\(count) card](inflect: true)")`. This
     produces a catalog key like `"^[%lld card](inflect: true)"`; the
     `zh-Hant-HK` translation is just `"%lld 張卡"` (no plural markup
     needed) and English gets automatic singular/plural for free. Only
     works because it's a *literal* `Text()` call (environment-locale
     resolution, not `String(localized:)`) — see recipe item 2's bug.
   - **Everywhere else** (computed properties, notification body text,
     anything returning a plain `String`) — inflection markdown is
     **not** reliably processed outside `Text()`'s markdown-parsing
     pipeline, so instead wrap the whole hand-branched ternary in
     `AppLocale.string(...)`, e.g. `AppLocale.string("\(count) use\(count
     == 1 ? "" : "s")")`, producing key `"%lld use%@"`. Translate once
     ignoring the `%@` (Chinese doesn't need it): `"%lld 次"`.
   Done for ~15 sites across Benefit usage/redemption UI and push
   notification text — see "Known-fixed bugs" below for the exact
   before/after and the file list.
6. **Proper nouns** — card names, merchant names, network names (Visa/
   Mastercard/...), product names ("Google Drive") — never translated,
   consistent with the project's existing card/merchant convention.
7. **Debug-only strings** (`Chur/Debug/*`, and any UI only reachable via an
   `#if DEBUG` gate, e.g. `UserDashboardView`'s floating dev menu + its
   Reset-All-Data alert) — out of scope entirely.
8. **Decorative/graphic content** — text baked into a fixed-layout
   `ImageRenderer` output (`PostcardView`'s shareable postcard image) or a
   purely cosmetic demo carousel (`OnboardingWelcomeStep`'s animated mock
   cards) — deferred; translating well needs a design pass on the asset,
   not just a catalog entry.

## Catalog maintenance notes

- Formatting: 2-space indent, `"key" : value` (space before colon) to match
  Xcode's own style — keeps future Xcode-driven edits diffing cleanly.
  After any scripted edit, re-sort keys alphabetically and re-run through
  `json.dump(..., ensure_ascii=False, indent=2, separators=(',', ' : '))`.
- Before adding a key, grep the target Swift file for the exact literal
  (`grep -oE '"[^"]*"' file.swift`) to make sure the catalog key matches
  byte-for-byte, including curly vs straight quotes/apostrophes and real
  `\n` escapes (Swift's `\n` compiles to an actual newline — a Python
  `"\n"` in a key matches that; don't second-guess it as a mismatch).
- Reuse keys across features when the English text is identical and means
  the same thing (e.g. `"Cancel"`, `"Done"`, `"Active"`, `"Custom"`,
  `"Benefits"` are each shared by many files) — don't duplicate.

## Progress

**Foundation (Phases 1-3): shipped.** String Catalog + `zh-Hant-HK`
registered, `AppLocale` seam, `User.languagePreference` + Settings UI +
backup sync (`ChurBackup.currentVersion = 2`).

**String migration (Phase 4): complete**, including News (see correction
below — it's live and in scope, not skipped) and pluralized/notification
strings and known business-logic-coupled labels (all fixed 2026-08-02).
Catalog currently has **622 keys** (`zh-Hant-HK` only) — grew from 432
after Pak Ho did a real Xcode build locally and pushed the result (Xcode
re-extracted the whole project and correctly generated `%1$@`/`%2$@`-style
positional format specifiers plus auto-generated context comments for every
interpolated string this migration had deferred by hand), then to 566 after
a follow-up translation pass, then to 622 after fixing the bugs described
under "Known-fixed bugs" below. A handful of Debug-only and 2 News strings
are still untranslated by design (see "Not started at all"). File-level
areas done, in order first migrated:

| Area | Files | Status |
|---|---|---|
| Settings (Display, Settings root) | 2 | ✅ |
| Onboarding (all 5 steps + container) | 6 | ✅ |
| Shared chrome (Home greeting, ProfilePhotoPicker) | 2 | ✅ |
| Cards (Add Card, wallet mgmt, Info tab pickers, card note) | 25 | ✅ |
| User (Account/Backup/Region/Notification/Reminder settings, delete/restore sheets, photo editor, Financial Aura picker, postcard share, support, dashboard, Month/Year breakdown) | 16 | ✅ |
| Benefit (checkbox row, detail sheet, progress bar, period mgmt, automation, log usage, usage history, benefits list, Expiring Soon) | 9 | ✅ |
| Badge (7 perk tools — Auto Rental, Car Rental, Cell Phone, Couponing, Hotel Status, Lounge Access, Trusted Traveler — + Transfer Partners + collection section) | 9 | ✅ |
| Home (category picker, Earning Power tab, Nearby state views) — `Parallaxheaderview.swift` needed no changes (all data-driven) | 6 | ✅ |
| Search (merchant detail popup, map/search view) — `NearbyMapPin`/`NearbyPlaceRow`/`OnlineMerchantRow` needed no changes (all data-driven) | 5 | ✅ |
| CardRecommendations (floating button, stack overlay, recommended card view) | 3 | ✅ |
| Core/RewardComponents (`EarningRatesSection.swift`, `RatePopupComponents.swift` — shared tile/row components used by both Cards and Home/CardRecommendations popups) | 2 | ✅ |
| Core/SignIn (`GoogleSignInButton.swift`) | 1 | ✅ |
| Core/CardSearchBar (`CardPickerCoreView.swift`) | 1 | ✅ |

Two adjacent files outside the Features tree were also touched because a Feature view called into them: `Chur/Features/Home/ViewModel/CategoryPickerViewModel.swift` (`cycleButtonLabel`) and `Chur/Features/CardRecommendations/DataModel/CardRecommendation.swift`'s `BonusRating` (checked, needed no change — `displayText` is star-emoji glyphs, no words).

**Explicitly out of scope (user decision, not a migration gap):**
- `Chur/Debug/*` (5 files) — dev-only tooling, per policy.

**Correction (2026-08-02): News is NOT out of scope** — earlier notes in this
doc said News "isn't shipping in this MVP, skip entirely," but it's actually
**live** on the Home screen (the "CHUR 新聞"/"CHUR NEWS" section with real
article cards) and turns out to already be almost fully translated — checked
every `Text`/`Button`/etc. literal across `Chur/Features/News/**/*.swift`
against the catalog and only 2 interpolated strings were missing (see below).
If a future report says News strings are untranslated, don't assume it's
"out of scope, ignore" — verify first.

**Not started at all:**
- **Phase 5 — Benefit JSON content**: all 268 files in
  `Chur/Resources/json/benefits/**/*.json` only have an `"en"` `localized`
  entry; the schema already supports `"zh-Hant-HK"` per file. Pure
  translation-content work, no code changes — `Benefit_LocalizedStrings.swift`
  already falls back to `"en"` gracefully. `Chur/Resources/json/categories/*.json`
  is the reference for what "done" looks like. **Not just a HK-only
  find-and-replace** — Pak Ho flagged (2026-08-02) that many benefits are
  region-specific (e.g. US-only cards/benefits), and translating US-only
  content to `zh-Hant-HK` isn't worth doing. Scope this by region before
  starting: figure out which of the 268 files' benefits are actually
  reachable by a HK-region user (via `RegionDatabase`/card availability),
  and prioritize/limit the translation pass to those.
- **Phase 6 — Cards/Merchants proper nouns**: deliberately deferred, no
  schema change planned.
- Debug-only interpolated strings (`Chur/Debug/*`, `View_CardAnalysisRow.swift`)
  remain untranslated by design (out of scope, see above). News's
  `"Spend \(record.spendingReq ?? ...)"` and `"Updated \(post.formattedDate)"`
  (in `NewsDetail_SharedComponents.swift`) are the only two News strings
  still untranslated — News itself is in scope (see correction above),
  these two just happen to be multi-part interpolations nobody has hand-verified
  the exact catalog key for yet.

**Known-fixed bugs worth remembering (don't reintroduce):**
- `AccountSettingsView`'s `Text(user.firstName.isEmpty ? "Not set" :
  user.firstName)` — a ternary with one dynamic (non-literal) branch
  forces SwiftUI to the verbatim `Text(String)` overload even though it
  looks like the same pattern as other in-place-extractable ternaries.
  Xcode's real build flagged this specific key as
  `extractionState: "stale"` (never actually reachable), which is how
  it was caught. When in doubt, check whether *both* ternary branches
  are string literals — if either branch is a variable/property, wrap
  the literal branch(es) in `String(localized:)`.
- All ~170 pre-existing `String(localized: "...")` call sites were
  missing `locale: AppLocale.current`, then (once that was fixed) hit
  the `String(localized:locale:)` runtime bug described in recipe item
  2 — see there for the full history. All now use `AppLocale.string(...)`.
- `Localizable.xcstrings`'s top-level `"version"` field oscillated
  between `"1.0"` and `"1.1"` across several commits/sessions — this
  was chased as a suspected bug at one point, but is **not** one:
  different Xcode versions normalize this field differently on save
  (confirmed by watching Pak Ho's own Xcode rewrite it back to `"1.1"`
  after a manual edit to `"1.0"`), and translations work correctly
  either way. Don't hand-edit this field or treat its value as
  meaningful; whatever Xcode's String Catalog editor writes on save is
  correct for that machine.
- `UserWalletSummaryView.swift`'s `statBox(title: String, ...)` helper
  had exactly the recipe-item-2 verbatim-`Text` gotcha (`"Annual Fees"`/
  `"Cards"`/`"Redeemed"` passed as raw string literals into a `String`
  parameter, then `Text(title)`) despite this file being in a row marked
  "✅" in the Progress table below — the table tracked file-level
  migration passes, not this per-call-site gotcha. Worth a repo-wide
  grep for `Text(<lowercaseIdentifier>)` where the identifier is a
  `String` parameter, next time a "translated in the catalog but not
  showing" report comes in for a file already marked done. This turned
  out to be exactly the "ANNUAL FEES / CARDS / REDEEMED untranslated"
  report Pak Ho raised — confirmed and fixed on-device 2026-08-02 (see
  above), not the `YearDetailSheet.swift` `.hidden()` badges or the
  `MonthDetailSheet.swift` stat pills, which were both already fine.
- `Badge.swift`'s `displayName`/`displayDescription` read `Locale.current`
  directly instead of going through `AppLocale` — see the new Architecture
  bullet above. Fixed in `b36adf4`; also wrapped `BadgeCategory.displayName`
  ("Lifestyle"/"Travel"/"Protections"), which was a bare hardcoded switch
  never localized at all. `BadgeTier.displayName` ("Locked"/"I"/"II"/"III")
  was checked and left alone — confirmed unused for display (`BadgeCard`
  only reads `tier.rawValue` for the progress dots).
- `AppLocale.string(...)` (like `String(localized:)` before it) supports
  string interpolation directly — you do **not** need to strip
  interpolation out and defer it. E.g. `AppLocale.string("Your
  \(selectedYear)")` produces a proper `"Your %lld"` catalog key, same
  shape Xcode's own extraction produces. Only defer a string if you
  can't safely hand-write its catalog key by inspection (multi-argument
  interpolations, since the positional numbering — `%1$@`, `%2$@` — is
  easy to get wrong by hand).
- **Push notification content was entirely missed by the original
  migration** — `ReminderScheduler.swift`, `ReminderScheduler_AnnualFee.swift`,
  `ReminderScheduler_Digest.swift`, `ExpiringBenefits.swift`'s `summary().totalText`.
  None of this showed up in a grep for `Text(`/`Label(` since it's
  `UNNotificationContent` title/subtitle/body strings, not SwiftUI views.
  Fixed 2026-08-02 (all wrapped in `AppLocale.string(...)`). Caught a
  bug the fix itself would have introduced: `ReminderScheduler_AnnualFee.swift`
  compared `relativeWhenText(...) == "today"` — once `"today"` is
  localized that comparison silently breaks. Added
  `ReminderScheduler.isToday(from:to:)` (duplicates the day-boundary
  math, not the localized string) for callers that need to branch on
  "is this today?" — **never string-compare the output of a function
  that returns `AppLocale.string(...)`.**
- **`CardTypeSelector`/`RegionSelector` filter options**: fixed for
  `CardTypeSelector` — `filterState.selectedCardType` doubles as a
  `UserDefaults` persistence key and a card-database filter key
  (lowercased into a lookup string in `Cards_Add_Card_ViewModel.swift`),
  so the identifier itself can't be translated. Added a
  `displayName(for:)` mapping used only at the 3 `Text`/`Label` call
  sites, identifier untouched — same pattern as `cardTypeDisplayLabel`.
  Checked `RegionSelector` too: its identifier is `region.id` (ISO
  code), `region.name` is pure display data never compared anywhere —
  no coupling bug there, nothing to fix.
- **`ParentCategoryPopup.headerLabel`**: fixed — was a raw `String`
  compared by exact value (`headerLabel == "SUB-CATEGORY"`) to pick an
  icon, and also displayed directly. Replaced with a
  `CategoryHeaderKind` enum (`.general`/`.subCategory`) exposing
  `displayLabel`/`icon` computed properties; the business logic never
  touches the localized string now.
- **Cards → Info tab labels were still English** despite the Progress
  table marking "Cards... Info tab pickers" done — that only covered
  the picker *sheets* (Network/Card Type/etc.), not the info-row labels
  themselves. `CardInfoContentView_CardInformationSection.swift`,
  `CardInfoContentView_FeesTermsSection.swift`, and
  `CardInfoContentView_UserNotes.swift` all passed raw literals into
  `DetailRow(label:)`/`CardSectionHeader(title:)` (both render via
  verbatim `Text(String)` — recipe item 2). The sibling file in the
  same tab, `CardInfoContentView_RewardSetupSection.swift`, was already
  done correctly, which is presumably why this slipped through — a
  file-level "done" checkmark doesn't guarantee every sibling file in
  the same folder was actually covered. Fixed 2026-08-02.

## How to resume in a new session

Phase 4's file-by-file migration is done, including News (see correction
above — it was never actually out of scope). Pluralization and the known
business-logic-coupled labels are also done (2026-08-02). What's left, in
rough priority order:

1. **Phase 5 — Benefit JSON content**, region-scoped. Don't just
   find-and-replace all 268 files — first work out which benefits a
   HK-region user can actually reach (via `RegionDatabase`/card
   availability), and limit the translation pass to those; translating
   US-only benefit content to `zh-Hant-HK` isn't worth doing. Pure
   content work otherwise, no code changes needed —
   `Benefit_LocalizedStrings.swift` already falls back to `"en"`
   gracefully. `Chur/Resources/json/categories/*.json` is the reference
   for what "done" looks like.
2. **The 2 remaining News interpolated strings** in
   `NewsDetail_SharedComponents.swift` (`"Spend ..."`, `"Updated ..."`)
   — compute their exact catalog keys the same way this session did for
   everything else (a standalone `swift` script evaluating
   `LocalizedStringResource(...)`, or an actual Xcode build), then
   translate.
3. **General audit technique, if a "still shows English" report comes in
   for an area marked done**: a file-level ✅ in the Progress table only
   means someone touched that file — it does *not* guarantee every
   custom-component call site in it was caught (see the `UserWalletSummaryView`
   and Cards Info-tab bugs above, both in files marked done). Grep the
   specific file for `Text(<lowercaseIdentifier>)` and
   `SomeComponent(label: "literal"` / `title: "literal"` patterns — a
   *raw string literal* passed into a custom component's `String`
   parameter (not `AppLocale.string(...)`) is the single most common
   recurring bug in this codebase. Also worth checking `Chur/Debug/*`-adjacent
   or non-View files (`Service/`, `ViewModel/`) for the same pattern —
   push notification content was missed entirely for exactly this
   reason (it's not `Text(`/`Label(`, so it never showed up in the
   obvious greps).
