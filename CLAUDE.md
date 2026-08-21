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
- `Chur/CONTENT_PUBLISHING_REFERENCE.md` — how to change card/reward JSON and publish it to `content.chur.app` without an App Store release: the commands, what's remote vs still bundle-only, verification, rollback, troubleshooting, and a git cheat sheet. **Read before editing seed JSON; update it whenever a domain becomes remote or the publish flow changes.**
- `Chur/ROADMAP.md` — growth priorities (P0 schema migration ✅ → P1 remote content pipeline ✅, P1c test vectors ✅ / contract spec deferred → **P1d pre-P2 additions, to be filled in** → P2 analytics → P3 annual card value → P4 widget), the Visa API assessment, and market sequencing. **Read before starting new feature work so it lands in priority order; update it whenever priorities shift or a phase completes.** Its "P1b — lessons worth keeping" section is the post-mortem for the whole content pipeline — read it before changing publishing, card art, or content refresh.
- `Chur/PRICING_VECTORS_REFERENCE.md` — the shared pricing-engine test vectors (`ChurTests/pricing-engine.json` + `ChurTests/PricingEngineVectorTests.swift`): fixture format, what each vector pins, the determinism rules, and how to add one. **Read before changing `Core/PricingEngine/` or `matchWeight` resolution; a failing vector is a question — engine wrong or expectation wrong — not a file to edit until green.**
- `Chur/LOCALIZATION_REFERENCE.md` — multi-language support: the `AppLocale` seam, `User.languagePreference`, String Catalog conventions, the verbatim-`Text(String)` gotcha, and per-feature migration progress/next steps. **Read before touching localization/`AppLocale.swift`/`Localizable.xcstrings`, or before continuing the UI string migration; update its progress table whenever a feature's strings are migrated.**

## Project layout

- `Chur/App/` — app entry (`ChurApp.swift`), config.
- `Chur/Core/` — cross-feature infrastructure: `Map/` (location + nearby places), `PricingEngine/` (reward rate calculation), `RewardComponents/` (shared reward UI), `SharedDesign/` (design system), `SignIn/`, `Sync/` (SwiftData schema, cloud backup, seed loading).
- `Chur/Features/<Feature>/` — one folder per feature, subdivided into `DataModel/`, `Service/`, `View/`, `ViewModel/`.
- `Chur/Debug/` — dev-only tools (time travel, reset, test data).
- `Chur/Resources/json/` — seed data (cards, categories, merchants, benefits, badges, control, recommendations). All of it publishes remotely except `control/SeedDataRegions.json` — see `CONTENT_PUBLISHING_REFERENCE.md`.
- `CardArt/`, `IconArt/` — **repo root, outside `Chur/` on purpose.** Source of truth for all artwork: one flat file per image, named for the name the JSON refers to, in subfolders that nothing reads. `CardArt/` holds card images; `IconArt/` holds badge, bank and partner icons (P1d). `Chur/` is a synchronized root group in the Xcode project, so art placed under it gets compiled back into the app and undoes the 27 MB that moving art to the CDN saved. Add new art here in Finder, not in Xcode.
- `Scripts/ChurContentPublish/` — the publisher (standalone SPM tool). Reads `Chur/Resources/json/` and `CardArt/`, writes `dist/`, uploads to R2.
- `ChurTests/` — unit test target (Swift Testing), a **synchronized folder**: anything dropped in joins the target automatically, JSON fixtures included. Currently the pricing-engine vectors (`pricing-engine.json` + `PricingEngineVectorTests.swift`) only. It sits outside `Chur/`, so nothing here reaches the shipping app.

Large types are split across files with an underscore suffix: `CardRateCalculator_Summary.swift`, `Benefit_logics.swift`, `BenefitUsageAnalyzer_Periods.swift`. Follow this pattern instead of letting one file grow.

## Data layer rules (SwiftData)

- Schema is versioned: `ChurSchemaV2_0` + `ChurMigrationPlan` in `Core/Sync/ChurSchema.swift`. **Any model change requires a new `VersionedSchema` + `MigrationStage`** — never mutate the current schema in place.
- New models must be registered in the schema's `models` list or they are silently not persisted (see `MerchantReward` — intentionally unregistered placeholder).
- Cloud backup DTOs (`CloudSyncManager`): new fields must be optional; breaking changes require bumping `ChurBackup.currentVersion` and adding a case in `migrate(_:)`.
- Models use application-level `id: String` keys for cross-references and sync (SwiftData's `PersistentIdentifier` is internal only).
- **Seed-data ids that persisted user data points at are permanent** — card ids, benefit ids, reward `planID`s, `configurableSlot`s and category ids. Renaming or removing one is destructive and silent (renaming a benefit id *deletes the user's redemption history* — `Benefit.usageHistory` cascades). `ChurContentPublish` refuses to publish when one disappears; see the load-bearing ids table in `DataDictionary.md` for the retire-don't-delete recipe.
- User-edited fields are protected from sync overwrite via `hasCustom*` flags (e.g. `hasCustomAnnualFee`, `hasCustomPointValue`). Preserve this pattern when adding syncable fields.

## Design system — always use, never hardcode

- **Colors:** the palette lives in two places — the asset catalog `Resources/Assets.xcassets/Colors/` (17 core brand colors like `churOlive`, `churGold`, `churOffWhite`; supports dark-mode variants; exposed via Xcode's auto-generated symbols) and `Color.chur*` extensions in `Core/SharedDesign/Experience/Colors.swift` (hex-defined, light-mode only). **Reuse an existing `chur*` color before adding one.** New colors that need dark-mode support go in the asset catalog; otherwise `Colors.swift`. Never inline hex in views.
- **Fonts:** `Font.chur*()` functions in `Core/SharedDesign/Experience/fonts.swift` — everything is SF Rounded. Never use raw `.system(size:)` in views. **The font set has grown too large — always reuse an existing `chur*` font before adding one.** Check `fonts.swift` for the size/weight you need first; a new function is only justified if no existing one matches, and it goes in `fonts.swift`, never inline in a view.
- **No artwork is in the app.** `Assets.xcassets/Cards` went in P1b, `Badges`/`Banks`/`Partners` in P1d — everything is published to the CDN and fetched on demand. **Never write `Image(someName)` or `UIImage(named: someName)` for card art or an icon**; both return nothing. Use `CardArtView(imageName:)` for cards and `IconArtView(imageName:)` for icons (both `SharedDesign/Components/`), which resolve bundle → memory → disk → CDN. The files live at repo-root `CardArt/` and `IconArt/` (see Project layout). `Assets.xcassets` still holds colors, the app icon and one UI image — those are unaffected.
  - **Choosing between the two is about the fallback.** Card art has one: a grey rectangle. Icons have many — a category emoji, an issuer name, an SF Symbol, or nothing — so `IconArtView` takes the fallback as a `@ViewBuilder` and each call site keeps its own.
  - **Deciding *what to draw* is a different question from whether art has loaded.** A site that branches on art existing — an SF Symbol vs. an image of the same name, a bare icon vs. a tiled one — must ask `CardArtLoader.shared.isKnown(_:)`, which consults the published index. `UIImage(named:)` answers nil for art that exists perfectly well on the CDN.
  - Five call sites survived the P1b conversion and rendered blank for a day, so when you add a render path, `grep -rn "Image(.*[Ii]mageName\|UIImage(named:"` before believing it's the only one.
- **Buttons:** `ScaleButtonStyle` / `SquishyButtonStyle` from `Style.swift`; shared controls like `ChurDoneButton` / `ChurCancelButton` (**every sheet's Done and Cancel, toolbar or overlay** — filled capsules sharing one `churActionChrome`, so they are always the same height — `churSageDeep` for confirm, `churRoseDeep` (#BA1A1A) for cancel, colour being the only difference; they replaced 30 hand-rolled copies). The capsule is the style **everywhere, toolbars included**. iOS 26 wraps each toolbar item in its own Liquid Glass container, which shows as a seam around the capsule — so every `ToolbarItem` holding one carries `.churBareToolbarBackground()`, the single guarded reference to `sharedBackgroundVisibility` in the app. Alert buttons using `role: .cancel` are system-styled and stay as they are, `OliveRingIconButton` (ring-outline circular icon button; `OliveRingIcon` for use as a `Menu` label), `ChurMenuSheet` / `ChurMenuRow` / `ChurMenuSectionHeader` (**the replacement for `Menu` on action lists and filters** — a small self-measuring bottom sheet that closes on selection; the row owns its own `dismiss()`. If a row opens *another* sheet, record the choice and act on it in `.sheet(onDismiss:)`, or the second sheet silently never appears), `RatePill`, `SheetDismissButton`, `EmptyStatePlaceholder`, `WaveDivider` live in `SharedDesign/Components/` — reuse before creating new ones.
- **Tool sheet banners:** `ToolSheetHeaderBanner` (`SharedDesign/Components/ToolSheetHeaderBanner.swift`) is the shared header for full-screen tool sheets (Couponing, Transfer Partners, Year/Month Summary, and the badge tools) — off-white background, olive dot/SF-Symbol pattern via `RepeatingPatternBackground`, grab handle, and `SheetDismissButton` baked in. Callers only supply title/pill/subtitle content. Reuse it for any new tool sheet instead of building a bespoke header.
- **Merchant / category / benefit popups — the sage hero family:** all three share one set in `Core/RewardComponents/RatePopupComponents.swift`. `PopupHeroHeader` (sage `churSage` hero, floating white avatar top-trailing, `showsAvatar:` for screens with no mark), `PopupSectionCard` (the white elevated layer, optional corner tab), `.popupHeroTitle()` / `.popupHeroInset()` (title in `churBlack`, text inset clear of the avatar), `.popupHeroOverlap()` (pulls a card up so it bites into the hero) and `.ambientCardShadow()`. Geometry lives in `PopupHeroMetrics` and `PopupCardMetrics` — **never write these numbers as literals**; the inset is derived from the avatar size, and the previous set drifted across three screens before it was extracted. Three rules that cost real time to learn: the hero fill bleeds `topBleed` upward so a ScrollView rubber-band reveals sage rather than the page behind it; the *card* overlaps the hero, not a slab wrapping the page; and **both** shapes need a radius, or the sage reads as a flat band. No `RepeatingPatternBackground` in these heroes.
- **Localization:** user-facing model content is localized as `en`, `zh-Hans`, `zh-Hant-HK`, `zh-Hant-TW` (see `Benefit.localized`, `SpendingCategory.name*`). New user-facing seed content needs all four. UI chrome strings (`Text`/`Label`/`Button`/`.navigationTitle` literals) belong in the String Catalog `Chur/Resources/Localizable.xcstrings` — currently only `en`/`zh-Hant-HK` are registered project locales; migrate existing hardcoded strings into the catalog incrementally as you touch a view, don't do a bulk rewrite. **Never read `Locale.current` directly in new code** — always go through `Chur/Core/Localization/AppLocale.swift` (`AppLocale.current`, `AppLocale.resolve(_:)`, `AppLocale.localePriorityKeys(for:)`), which is the single seam that keeps UI strings and model-content resolution (`Benefit`, `SpendingCategory`, `Badge`) in sync with the user's `User.languagePreference` override. Card and merchant names (`Resources/json/cards/`, `Resources/json/merchants/`) are intentionally not localized — they're proper nouns. See `Chur/LOCALIZATION_REFERENCE.md` for the full migration recipe, gotchas, and progress tracker.

## Code style

- Swift async/await only — **no Combine**.
- 4-space indent, PascalCase types, camelCase members, `@State private var` for view state, no force unwrapping.
- SwiftUI views conform to `View` with UI in `body`; keep separation between View / ViewModel / Service / DataModel folders.
- Use `Date.current()` (mockable, see `Debug/Testing/Date+Testing.swift`) instead of `Date()` in logic that tests or the time-travel debug tool need to control.
- Tests: Swift Testing framework for unit tests, XCUIAutomation for UI tests. Unit tests live in the `ChurTests` target; data-driven fixtures go beside them in `ChurTests/` and are read out of the test bundle — tests run inside the simulator, which cannot reach paths on the host Mac, so `#filePath` alone does not work.

## Git workflow

- Pak Ho is new to git/GitHub — Claude handles git operations and briefly explains what it's doing. Remote: `origin` → `github.com/churfinancial-owner/chur`, single branch `main`.
- Commit whenever a change works and builds green; push at the end of each session (treat "commit and push" as the session-close routine). Never let work sit uncommitted for long.
- Work directly on `main`; create a branch only for risky work (schema migrations, large refactors) and merge when done.
- Never commit secrets (tokens, keys); add any local secret files to `.gitignore` before creating them.

## Validation

- Build with the Xcode `BuildProject` tool; use `XcodeRefreshCodeIssuesInFile` for quick per-file checks.
- If a schema change breaks the store during development, the fix is deleting the app from the simulator (see `ChurApp.swift` fatalError hint) — but shipped changes always need a real migration stage.
