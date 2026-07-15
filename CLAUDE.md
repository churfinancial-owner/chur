# Chur

iOS app (SwiftUI + SwiftData) that finds the best credit card to use at the place the user is shopping. Location via MapKit → merchant category → pricing engine matches card reward rates. Also tracks card benefits, badges/status tools, and backs up to Google Drive.

## Execution rules — token efficiency

You are a token-conscious engineering assistant. Balance thorough, holistic code quality with strict token efficiency by following these rules:

### 1. Diagnose & trace dependencies first
- Before proposing a solution, inspect the primary files and trace their direct dependencies, imports, or callers. Do not go too far beyond.
- Understand the downstream impacts of your changes so you don't introduce breaking changes elsewhere in the codebase.

### 2. Present the blueprint before coding
- Once discovery is complete and you understand the context, STOP. Do not write any code yet.
- Provide a concise 3-to-5 bullet-point plan summarizing:
  - What changes you will make to the primary file.
  - Which dependent files, types, or tests must be updated alongside it.
- End the plan explicitly with: "Reply 'GO' to execute, or provide feedback."

### 3. Surgical code modifications (no whole-file rewrites)
- Once approved to build, do not rewrite unchanged code.
- Output only the specific functions, blocks, or lines being modified. Use clear markers like `// ... existing code ...` to skip the parts that aren't changing.

### 4. Code first, skip the conversational fluff
- Dive straight into the code or the plan. No conversational intros ("Sure, I can help with that!") or lengthy post-code explanations of how a language feature works.
- Let clean code and minimal comments speak for themselves. If Pak Ho wants an explanation, he will explicitly ask.

### 5. Stop and ask on friction
- If a test fails repeatedly, or you hit an unexpected architectural conflict, do not loop through speculative fixes or guess wildly. Stop immediately, explain the hurdle in one sentence, and ask for guidance.

## Key reference docs — read before touching related code

- `Chur/DataDictionary.md` — full data model reference (every @Model, field, relationship, audit notes). **Update it whenever a model or schema changes.**
- `Chur/MERCHANT_SETUP_REFERENCE.md` — how to add merchants/categories to the seed JSON so the pricing engine matches correctly. Follow it exactly; `matchWeight` resolution order is documented there.
- `Chur/REWARD_SETUP_REFERENCE.md` — cheatsheet for authoring reward JSON: all patterns (plain/multi-category, groupLabel display grouping, configurable slots, rotating, plans) and their gotchas. **Update it whenever a reward JSON field or pattern changes.**
- `Chur/NOTIFICATION_SYSTEM_REFERENCE.md` — how local reminder notifications work (reconciliation model, categories, timing rules, digest, tap routing, how to add a category). **Read before touching `Reminder*` files or notification settings; update it whenever a category, timing rule, or routing behavior changes.**
- `Chur/MAP_SEARCH_REFERENCE.md` — how nearby/map merchant search works (bucketed parallel MapKit search, caps, category matching). **Read before touching `Core/Map/Mapkit_*`, `Nearby_Engine*`, or `Features/Search/*`; update it whenever a bucket, cap, or POI category mapping changes.**

## Project layout

- `Chur/App/` — app entry (`ChurApp.swift`), config.
- `Chur/Core/` — cross-feature infrastructure: `Map/` (location + nearby places), `PricingEngine/` (reward rate calculation), `RewardComponents/` (shared reward UI), `SharedDesign/` (design system), `SignIn/`, `Sync/` (SwiftData schema, cloud backup, seed loading).
- `Chur/Features/<Feature>/` — one folder per feature, subdivided into `DataModel/`, `Service/`, `View/`, `ViewModel/`.
- `Chur/Debug/` — dev-only tools (time travel, reset, test data).
- `Chur/Resources/json/` — seed data (cards, categories, merchants, benefits).

Large types are split across files with an underscore suffix: `CardRateCalculator_Summary.swift`, `Benefit_logics.swift`, `BenefitUsageAnalyzer_Periods.swift`. Follow this pattern instead of letting one file grow.

## Data layer rules (SwiftData)

- Schema is versioned: `ChurSchemaV1_10` + `ChurMigrationPlan` in `Core/Sync/ChurSchema.swift`. **Any model change requires a new `VersionedSchema` + `MigrationStage`** — never mutate the current schema in place.
- New models must be registered in the schema's `models` list or they are silently not persisted (see `MerchantReward` — intentionally unregistered placeholder).
- Cloud backup DTOs (`CloudSyncManager`): new fields must be optional; breaking changes require bumping `ChurBackup.currentVersion` and adding a case in `migrate(_:)`.
- Models use application-level `id: String` keys for cross-references and sync (SwiftData's `PersistentIdentifier` is internal only).
- User-edited fields are protected from sync overwrite via `hasCustom*` flags (e.g. `hasCustomAnnualFee`, `hasCustomPointValue`). Preserve this pattern when adding syncable fields.

## Design system — always use, never hardcode

- **Colors:** the palette lives in two places — the asset catalog `Resources/Assets.xcassets/Colors/` (17 core brand colors like `churOlive`, `churGold`, `churOffWhite`; supports dark-mode variants; exposed via Xcode's auto-generated symbols) and `Color.chur*` extensions in `Core/SharedDesign/Experience/Colors.swift` (hex-defined, light-mode only). **Reuse an existing `chur*` color before adding one.** New colors that need dark-mode support go in the asset catalog; otherwise `Colors.swift`. Never inline hex in views.
- **Fonts:** `Font.chur*()` functions in `Core/SharedDesign/Experience/fonts.swift` — everything is SF Rounded. Never use raw `.system(size:)` in views. **The font set has grown too large — always reuse an existing `chur*` font before adding one.** Check `fonts.swift` for the size/weight you need first; a new function is only justified if no existing one matches, and it goes in `fonts.swift`, never inline in a view.
- **Buttons:** `ScaleButtonStyle` / `SquishyButtonStyle` from `Style.swift`; shared controls like `OliveIconButton`, `RatePill`, `SheetDismissButton`, `EmptyStatePlaceholder` live in `SharedDesign/Components/` — reuse before creating new ones.
- **Localization:** user-facing model content is localized as `en`, `zh-Hans`, `zh-Hant-HK`, `zh-Hant-TW` (see `Benefit.localized`, `SpendingCategory.name*`). New user-facing seed content needs all four.

## Code style

- Swift async/await only — **no Combine**.
- 4-space indent, PascalCase types, camelCase members, `@State private var` for view state, no force unwrapping.
- SwiftUI views conform to `View` with UI in `body`; keep separation between View / ViewModel / Service / DataModel folders.
- Use `Date.current()` (mockable, see `Debug/Testing/Date+Testing.swift`) instead of `Date()` in logic that tests or the time-travel debug tool need to control.
- Tests: Swift Testing framework for unit tests, XCUIAutomation for UI tests.

## Git workflow

- Pak Ho is new to git/GitHub — Claude handles git operations and briefly explains what it's doing. Remote: `origin` → `github.com/churfinancial-owner/chur`, single branch `main`.
- Commit whenever a change works and builds green; push at the end of each session (treat "commit and push" as the session-close routine). Never let work sit uncommitted for long.
- Work directly on `main`; create a branch only for risky work (schema migrations, large refactors) and merge when done.
- Never commit secrets (tokens, keys); add any local secret files to `.gitignore` before creating them.

## Validation

- Build with the Xcode `BuildProject` tool; use `XcodeRefreshCodeIssuesInFile` for quick per-file checks.
- If a schema change breaks the store during development, the fix is deleting the app from the simulator (see `ChurApp.swift` fatalError hint) — but shipped changes always need a real migration stage.
