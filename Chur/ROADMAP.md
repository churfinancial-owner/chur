# Chur Roadmap

Growth priorities and the reasoning behind them. **Update whenever priorities shift or a phase completes.**

Last reviewed: 2026-08-05.

---

## 1. Where Chur stands today

| | |
|---|---|
| **What it does** | Per-dollar, point-of-sale ranker — "which card should I use at this merchant, right now" |
| **Data** | 175 cards, 268 benefit templates, 193 categories, 77 merchants — ~500 JSON files in `Resources/json/`, all bundled into the binary |
| **Persistence** | On-device SwiftData (`ChurSchemaV1_14`) + Google Drive appDataFolder backup |
| **Backend** | None. Two outbound calls only: Google Drive (`Core/Sync/CloudSyncManager.swift`) and Sanity CMS (`Features/News/Service/NewsService.swift`) |
| **Analytics** | None |
| **Monetization** | None active. `CardRecommendation.affiliateURL` and `OnlineMerchant.affiliateID` exist but are dormant |

**Built and switched off:**

| Feature | Where | State |
|---|---|---|
| Card recommendations | `Features/CardRecommendations/` | Engine complete; all 6 `rec_*.json` are `isActive: false`, so `recommend()` returns empty |
| News feed | `Features/News/` | `FeatureFlags.homeNewsFeedEnabled = false` (`App/Config.swift`) |
| Sanity CMS pipe | `Features/News/Service/NewsService.swift` | Live, already models `offerHistory` with all-time-high flags — unused |

## 2. The differentiator

"Which card now" is table stakes — CardPointers, MaxRewards and Kudos all do it, all funded, all US.

What they don't have is Chur's **benefit ledger**: `Benefit` + `BenefitUsageRecord` model frequency, `resetType` (calendar vs card anniversary), per-period budgets, and a full redemption history, analyzed across the five `BenefitUsageAnalyzer*` files. That's a genuinely deeper model of card perks than anything in the category.

The gap: `CreditCard.annualFee` and redeemed value **never meet in code**. `Features/User/View/MonthlyBreakdown/UserWalletSummaryView.swift` shows both numbers side by side with no verdict. Closing that is P3.

## 3. Priority stack

### P0 — Fix the SwiftData migration blocker

Every `ChurSchemaV1_10`…`ChurSchemaV1_14` enum in `Core/Sync/ChurSchema.swift` lists the **same live `@Model` classes**, so staged migration can never actually run. `App/ChurApp.swift:42` then `fatalError`s in release with no recovery path.

See `DataDictionary.md` audit note 1b for the full write-up.

- **Why:** P3 and P4 both add persistence and are blocked behind it.
- **Cost of not doing it:** the first schema change after launch wipes real users' wallets and benefit history, with a hard crash and no recovery. Unrecoverable in the field.

### P1 — Remote content pipeline

CDN-hosted aggregated JSON bundles + a version manifest, with the bundled JSON retained permanently as offline fallback.

- Client contract stays **the JSON shapes that already exist**, so the hosting choice stays swappable and a future Android app consumes the identical manifest — no second API.
- New `ContentStore` resolver (cache-first, bundle-fallback) replaces the 30 `Bundle.main` call sites. **Stage A covers only `Features/Cards/DataModel/CardDatabase.swift` and `Features/Benefit/DataModel/Setup/BenefitDatabase_Loading.swift`** — the domains that actually change often. Everything else migrates later.
- Propagation into user wallets is already built: `Core/Sync/CardSyncService.swift` → `syncWalletCards(modelContext:)` reconciles against updated templates and already protects user edits via the `hasCustom*` flags.
- Write the content cache into an **App Group container from day one** — P4's widget needs to read it, and retrofitting means redoing the write path.
- Safety: reject any payload failing sha256 or decode, keep the previous cache, gate old clients with `minAppVersion`. A bad publish must never brick the app.

**Architectural invariant — do not break:** the app only ever reads static JSON from the CDN. It never queries a database or CMS directly. This is what keeps the authoring layer swappable, stops a vendor outage from breaking app launches, and lets Android consume the identical files.

**Shipping split:**

| | Scope |
|---|---|
| **P1a** | Publish script + R2 bucket + `Core/Content/` (4 files) + App Group entitlement + cards & rewards wired. Prove the loop end-to-end by changing one rate. |
| **P1b** | Benefits domain, card art published to CDN, Settings row showing content version + manual refresh, `Debug/Testing/SeedDataValidator.swift` extended to validate candidate payloads. |
| **P1c** | Written JSON contract spec + shared pricing-engine test vectors (see §5 Android). |

- **Why:** a wrong reward rate currently cannot be fixed without an App Store release, and offers change weekly.
- **Cost of not doing it:** data goes stale between releases — the one thing that destroys trust in a card app. Plus every Android feature gets rebuilt from scratch.

### P2 — Analytics baseline

Adopt **TelemetryDeck** (Swift-first, privacy-focused; free to 100k signals/mo, €9 for funnels and retention). Track content refresh success/failure, version applied, and screen views.

Deliberately *not* a homegrown events table — that gives rows, not funnels, retention or cohorts, all of which would then have to be built by hand.

- **Why:** the app is currently blind to all usage.
- **Cost of not doing it:** every decision below this line is guesswork, and there's no way to tell whether P3 or P4 worked.

### P3 — Annual card value

Join `CreditCard.annualFee` + benefit budgets (`BenefitUsageAnalyzer_Balance.periodBudget()` / `budget(for:)`) + realized `BenefitUsageRecord.redeemedAmount` + `CardRateSummary.effectiveCashBackRate` + a new self-reported spend profile.

Outputs: per-card keep / review / downgrade verdict; wallet-level "left on the table" (unredeemed budget this period) and "misrouted spend" (you'd earn $Y more using card Z for groceries).

- Requires a new persisted field on `User` (spend profile) → **blocked on P0**.
- Also upgrades `CardRecommendationEngine.recommend()` from taste-based (`strategyPreferences` only) to spend-aware. Note its weights don't sum to 1 — issuer diversity is `0.5`, larger than strategy match at `0.45`, likely a typo to fix while there.
- Surfaces in `UserWalletSummaryView` and Card Info; the net-value number should also flow into `SharePostcardView` — it's the most shareable number in the category.

- **Why:** this is the moat. It uses the one asset competitors don't have.
- **Cost of not doing it:** Chur stays a "which card now" app, competing head-on with three funded incumbents on their strongest feature.

### P4 — Widget

Best-card-for-category (`AppIntent`-configurable) + expiring-benefit countdown driven by `Features/Benefit/Service/ExpiringBenefits.swift`.

- Needs a Widget Extension target, entitlements (none exist today), and moving `ModelConfiguration` to a `groupContainer` — which relocates the store file and needs a one-time migration → **blocked on P0**.
- **Why:** `ReminderScheduler` already drives the retention loop; a widget gives it a home-screen surface.
- **Cost of not doing it:** lowest-stakes item here. Upside, not a gap.

## 4. Stack decisions

| Need | Choice | Cost |
|---|---|---|
| Serving content bundles | Cloudflare R2 + CDN | $0 (10 GB storage, zero egress) |
| Authoring | Repo JSON to start; add TinaCMS or Decap **only when** hand-editing hurts | $0 |
| Analytics | TelemetryDeck | €0–9/mo |
| Server-side compute | None needed. Cloudflare Workers ($5/mo) if that changes | — |

**Rejected:** Sanity (owner preference). Supabase — its edge over plain file hosting was server compute, an analytics sink, and a table editor; the first two are no longer needed, and the third partly evaporates because reward plans normalize into `jsonb` and render as raw JSON text anyway. Not worth $25/mo plus a week of schema modelling. Firebase (painful nested-document editing, fights bulk publish), Airtable (per-seat cost + API rate limits), self-hosted PocketBase (a VPS to operate).

**Visa APIs — dropped.** VMORC, Visa Offers Platform and the Digital Benefits Platform are all issuer- or merchant-gated. Merchant Search/Locator is obtainable and would give real MCC data (better than the hand-written prefix/contains patterns in `Resources/json/merchants/SeedDataGenericMappings.json`), but it needs mutual TLS and therefore a server. Revisit only if a server exists for other reasons.

## 5. Android

A second client is planned. Three things must be true of P1 or Android becomes a rewrite rather than a port.

**a. The JSON contract is the spec, not the Swift types.** `_CardJSON`, `_RewardStructure` and `BenefitTemplate` currently *define* the format by virtue of being what decodes it. Write the contract down (a versioned schema doc, or JSON Schema) so Android implements against a spec rather than reverse-engineering Swift. Silent drift here breaks one platform without failing a build.

**b. Card art has to move to the CDN.** iOS resolves art via `UIImage(named:)` from `Assets.xcassets/Cards/`. If art stays bundled per-platform, adding a card requires shipping *both* apps — which defeats the point of remote content. Publishing images alongside the data gives one source of truth and lets either platform pick up new cards without a release. Note two call sites use bare `Image(name)` with no fallback (`Core/RewardComponents/PerkToolComponents.swift:24`, `Features/News/View/NewsDetail_CardComponents.swift:15`) and will render blank for unknown art.

**c. The pricing engine needs shared test vectors.** `Core/PricingEngine/CardRateCalculator.swift` is the highest-risk port: 5-tier `matchWeight` resolution, `excludeFromParent` stops, channel filters, cross-border FX subtraction, boost overlays. Reimplementing it in Kotlin from reading Swift will drift. Ship a fixture file of `(cards, category, expected ranking)` cases that **both** platforms run as tests — cheap to write now, and it's the only thing that keeps the two engines honest.

Already cross-platform and fine as-is: model-content localization lives in the JSON, and the Google Drive `appDataFolder` backup (`Core/Sync/CloudSyncManager.swift`) uses a versioned `ChurBackup` DTO against an API Android has too.

## 6. Market sequencing

US / English first, then HK, TW, AU, UK, CA.

Current data skew to close before expanding:

| Region | Cards | Notes |
|---|---|---|
| US | 157 | Deep — 268 benefits, all recommendation content |
| HK | 15 | Rewards JSON exists for Citibank, Hang Seng, HSBC, Standard Chartered |
| CA | 3 | Amex only |

Recommendation content is US-only *and* all `isActive: false`, so the engine returns nothing in every market today.

Localization already covers `en`, `zh-Hans`, `zh-Hant-HK`, `zh-Hant-TW` for model content — see `LOCALIZATION_REFERENCE.md`. UI chrome is only registered for `en` / `zh-Hant-HK`.

## 7. Open questions

- **Monetization posture.** Affiliate (`CardRecommendation.affiliateURL` already exists), subscription, or neither. Undecided.
- **When Android starts.** P1c (contract spec + test vectors) is cheap to write during P1 and expensive to retrofit once two engines have already drifted — so it should be done on the iOS timeline regardless of when Android actually begins.
- **No test target exists.** At minimum, P1's validation/rejection paths and P3's value calculator need coverage — those are where a silent bug either bricks content or misstates money.
