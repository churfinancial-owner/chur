# Localization Reference

How Chur's multi-language support is built, what's done, what's left, and the
patterns to follow when migrating the rest. Read this before touching UI
strings or locale-resolution logic. **Update it whenever the architecture,
progress, or a new gotcha changes.**

Branch: `claude/app-localization-setup-mzadsw`. Full plan lives in
`/root/.claude/plans/look-at-the-latest-cosmic-hejlsberg.md` (Phase 1-3
engineering foundation — already shipped, see below) and the fuller
roadmap discussed in chat (Phase 4 = this string migration, Phase 5 =
benefit-JSON translation content, Phase 6 = Cards/Merchants proper nouns
deferred, Phase 7 = docs).

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
   catalog. Fix: wrap the literal in
   `String(localized: "...", locale: AppLocale.current)` at the point
   it's first assigned/passed — not at the `Text()` call site. **Always
   pass `locale: AppLocale.current` explicitly — never bare
   `String(localized: "...")`.** `String(localized:)` defaults its
   `locale:` parameter to `Locale.current` (the device's *system*
   language) and does **not** participate in SwiftUI's
   `.environment(\.locale, ...)` the way a literal `Text("...")` does.
   A first pass of this migration used the bare form everywhere, which
   quietly ignored the in-app Language override for every one of those
   ~170 call sites (they'd only look translated if the device's system
   language happened to already match) — caught only once Xcode's real
   build flagged the mismatch. Already fixed project-wide; keep the
   `locale:` argument on every future occurrence of this pattern.
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
   by hand without Xcode's own extraction to verify against (no
   Xcode/xcodebuild in this container) — defer those specifically rather
   than guess the numbering. Most single- and multi-argument strings from
   the original migration pass were later filled in after Pak Ho's local
   Xcode build re-extracted the whole project correctly (see Progress) —
   only a few Debug-only/News ones remain unfilled by design.
5. **Pluralized counts** ("1 card" vs "N cards", "N benefit(s)", "N day(s)")
   — needs a stringsdict-style plural variation in the catalog (Chinese has
   no plural forms, so the fallback English pattern doesn't translate
   1:1). Still not done anywhere — requires Xcode's plural-variation UI,
   not a plain string substitution; flagged at each occurrence, not migrated.
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

**String migration (Phase 4): complete except News (explicitly out of
scope — not shipping in this MVP).**
Catalog currently has **566 keys** (`zh-Hant-HK` only) — grew from 432
after Pak Ho did a real Xcode build locally (this container has no
Xcode/xcodebuild) and pushed the result: Xcode re-extracted the whole
project and correctly generated `%1$@`/`%2$@`-style positional format
specifiers plus auto-generated context comments for every interpolated
string this migration had deferred by hand. Most of those got
translated (by Pak Ho and in a follow-up pass here); a few Debug-only
and News ones are still untranslated by design. Done, in order:

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
- **News** (5 files) — feature isn't shipping in this MVP, skip entirely.
- `Chur/Debug/*` (5 files) — dev-only tooling, per policy.

**Not started at all:**
- **Phase 5 — Benefit JSON content**: all 268 files in
  `Chur/Resources/json/benefits/**/*.json` only have an `"en"` `localized`
  entry; the schema already supports `"zh-Hant-HK"` per file. Pure
  translation-content work, no code changes — `Benefit_LocalizedStrings.swift`
  already falls back to `"en"` gracefully. `Chur/Resources/json/categories/*.json`
  is the reference for what "done" looks like.
- **Phase 6 — Cards/Merchants proper nouns**: deliberately deferred, no
  schema change planned.
- A handful of interpolated strings only found via Xcode's real
  extraction remain untranslated by design: Debug-only ones
  (`Chur/Debug/*`, `View_CardAnalysisRow.swift`) and News's
  `"Spend %@ • Fee %@"` (News out of scope). Everything else Xcode
  extracted got translated.
- **Business-logic-coupled labels** flagged during migration still need
  a proper display-label split before they can be translated safely —
  see recipe item 3. Known instances: `ParentCategoryPopup.headerLabel`
  ("GENERAL CATEGORY"/"SUB-CATEGORY", compared by exact string equality
  to pick an icon), `CardTypeSelector`/`RegionSelector` filter options.

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
  missing `locale: AppLocale.current` — see recipe item 2. Fixed
  project-wide; don't reintroduce the bare form.
- `Badge.swift`'s `displayName`/`displayDescription` read `Locale.current`
  directly instead of going through `AppLocale` — see the new Architecture
  bullet above. Fixed in `b36adf4`; also wrapped `BadgeCategory.displayName`
  ("Lifestyle"/"Travel"/"Protections"), which was a bare hardcoded switch
  never localized at all. `BadgeTier.displayName` ("Locked"/"I"/"II"/"III")
  was checked and left alone — confirmed unused for display (`BadgeCard`
  only reads `tier.rawValue` for the progress dots).
- `String(localized:)` supports string interpolation directly — you do
  **not** need to strip interpolation out and defer it. E.g.
  `String(localized: "Your \(selectedYear)", locale: AppLocale.current)`
  produces a proper `"Your %lld"` catalog key, same shape Xcode's own
  extraction produces. Only defer a string if you can't safely hand-write
  its catalog key by inspection (multi-argument interpolations, since the
  positional numbering — `%1$@`, `%2$@` — is easy to get wrong by hand).

## Open question (unresolved as of this session)

Pak Ho reported seeing "ANNUAL FEES" / "CARDS" / "REDEEMED" untranslated
on the Month/Year breakdown screen. In current source
(`YearDetailSheet.swift`), those three `headerBadge(...)` calls are
wrapped in `.hidden()` — invisible (opacity 0) but still reserving
layout space — so they shouldn't render at all, translated or not.
Likely explanation: he was actually seeing the **visible** "Fees"/
"Redeemed" stat pills in `MonthDetailSheet.swift`'s `summaryStatPill`,
which *were* real and were affected by the `String(localized:)` locale
bug — but that was fixed in the same session (`f80281d`), before this
was raised, so it should already be resolved on his next pull. If he
reports this again after pulling past `f80281d`, get a screenshot —
don't assume it's the same root cause without confirming.

## How to resume in a new session

Phase 4's file-by-file migration is done except News (skipped by user
decision). What's left is follow-up work, in rough priority order:

1. **Remaining pluralized counts** — most interpolated strings were
   resolved this session (Xcode's real build extracted them correctly
   with `%1$@`/`%2$@` positional specifiers, and nearly all got
   translated — see Progress above). What's left is specifically
   **plural-variation strings** ("1 card" vs "N cards", "N benefit(s)",
   "N day(s)", "N Entry/Entries") — Chinese has no plural forms, so
   these need the catalog's plural-category variation UI in Xcode
   (device categories: one/other), not a plain string substitution.
   Also worth a spot-check in Xcode for any row still marked "New" —
   run a build, open the String Catalog editor, filter by state.
2. **Phase 5 — Benefit JSON content**: translate the 268
   `Chur/Resources/json/benefits/**/*.json` files' `localized["zh-Hant-HK"]`
   entries (pure content work, prioritize by most-held cards' benefits
   first if a usage signal is available).
3. **Business-logic-coupled labels deferred during migration** — e.g.
   `ParentCategoryPopup.headerLabel` ("GENERAL CATEGORY"/"SUB-CATEGORY"),
   `CardTypeSelector`/`RegionSelector` filter options — each needs a
   proper identifier/display-label split (like `cardTypeDisplayLabel`)
   before it can be translated safely.
4. If News ships later after all: same recipe as every other feature —
   read each file, classify every literal against the 8 categories
   above, wrap verbatim sites, batch-add catalog entries, verify
   (JSON validity + exact-literal cross-check + paren/brace balance —
   no Xcode/xcodebuild in this container to compile-check), commit per
   feature.
