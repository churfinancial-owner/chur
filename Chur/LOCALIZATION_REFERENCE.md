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
   catalog. Fix: wrap the literal in `String(localized: "...")` at the
   point it's first assigned/passed — not at the `Text()` call site. This
   has hit: computed properties returning conditional strings
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

**String migration (Phase 4): in progress, feature-by-feature.**
Catalog currently has **286 keys** (`zh-Hant-HK` only). Done, in order:

| Area | Files | Status |
|---|---|---|
| Settings (Display, Settings root) | 2 | ✅ |
| Onboarding (all 5 steps + container) | 6 | ✅ |
| Shared chrome (Home greeting, ProfilePhotoPicker) | 2 | ✅ |
| Cards (Add Card, wallet mgmt, Info tab pickers, card note) | 25 | ✅ |
| User (Account/Backup/Region/Notification/Reminder settings, delete/restore sheets, photo editor, Financial Aura picker, postcard share, support, dashboard, Month/Year breakdown) | 16 | ✅ |

**Remaining (~41 files, not started):**

| Area | Files |
|---|---|
| Benefit | 9 |
| Badge (Couponing, Cell Phone Protection, etc. tools) | 9 |
| Home | 6 |
| Search | 5 |
| News | 5 |
| CardRecommendations | 3 |
| Core/RewardComponents (`EarningRatesSection.swift`, `RatePopupComponents.swift`) | 2 |
| Core/SignIn (`GoogleSignInButton.swift`) | 1 |
| Core/CardSearchBar (`CardPickerCoreView.swift`) | 1 |

Excluded from scope entirely: `Chur/Debug/*` (5 files, dev-only tooling).

**Not started at all:**
- **Phase 5 — Benefit JSON content**: all 268 files in
  `Chur/Resources/json/benefits/**/*.json` only have an `"en"` `localized`
  entry; the schema already supports `"zh-Hant-HK"` per file. Pure
  translation-content work, no code changes — `Benefit_LocalizedStrings.swift`
  already falls back to `"en"` gracefully. `Chur/Resources/json/categories/*.json`
  is the reference for what "done" looks like.
- **Phase 6 — Cards/Merchants proper nouns**: deliberately deferred, no
  schema change planned.
- **Interpolated strings / pluralized counts** flagged throughout the
  migrated files above (see recipe items 4-5) — need a real Xcode build
  pass to auto-extract correctly rather than hand-authoring.

## How to resume in a new session

1. Check out `claude/app-localization-setup-mzadsw` (already the active
   branch — don't create a new one unless this PR has since merged).
2. Pick the next feature from the "Remaining" table (Benefit is the
   natural next one — same size class as User/Cards).
3. For each file: read it in full, classify every `Text`/`Label`/`Button`/
   `.navigationTitle`/`Toggle`/`Section`/`.alert`/`TextField` literal
   against the 8 recipe categories above, apply code edits (recipe #2/#3)
   where needed, then batch-add catalog entries via a small Python script
   (see commit history for the pattern — `git log --oneline` on this
   branch shows one commit per feature migrated).
4. Verify: JSON validity (`python3 -c "import json; json.load(open(...))"`),
   exact-literal cross-check against source (`grep -oE '"[^"]*"'` per file,
   diff against new catalog keys), and paren/brace balance on every edited
   Swift file (no Xcode/xcodebuild available in this container to
   compile-check).
5. Commit per feature (not one giant commit) — matches the existing
   history and makes review/rollback easy. Push after each.
