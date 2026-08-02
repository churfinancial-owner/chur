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
- **`Benefit.localized` / `SpendingCategory.name*`** (pre-existing
  model-content localization) now resolve through `AppLocale` instead of
  independently branching on `Locale.current` — see
  `Benefit_LocalizedStrings.swift` / `SpendingCategory.swift`.

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
4. **Interpolated `Text("... \(x) ...")` / alert messages** — **deliberately
   deferred, not hand-authored.** Xcode's String Catalog stores these with a
   `substitutions` structure keyed by argument position, which is easy to
   get subtly wrong by hand (no Xcode/xcodebuild available in this
   container to verify). Every occurrence found so far has been left
   alone and is tracked as a follow-up requiring a real Xcode build to
   auto-extract correctly. Examples: "Reset to default (\(value))",
   "Are you sure you want to delete \(card.name)?...", "Saved \(date)",
   "\(rate) \(category) ✨".
5. **Pluralized counts** ("1 card" vs "N cards", "N benefit(s)", "N day(s)")
   — needs a stringsdict-style plural variation in the catalog (Chinese has
   no plural forms, so the fallback English pattern doesn't translate
   1:1). Not yet done anywhere — flagged at each occurrence, not migrated.
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
Catalog currently has **563 keys** (`zh-Hant-HK` only) — grew from 432
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

## How to resume in a new session

Phase 4's file-by-file migration is done except News (skipped by user
decision). What's left is follow-up work, in rough priority order:

1. **Interpolated strings and pluralized counts** — every migrated file
   above has some deferred (see recipe items 4-5): "Reset to default
   (\(value))", "Are you sure you want to delete \(name)?", "N card(s)",
   "N use(s)", date-formatted subtitles, etc. This needs an actual Xcode
   build (not available in this container) to let Xcode auto-extract the
   correct `substitutions`/plural-variation structure into
   `Localizable.xcstrings`, then translate each. Do this on a machine
   with Xcode: open the project, build, open the String Catalog editor,
   fill in `zh-Hant-HK` for every row still marked "New".
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
