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

- **Why:** a wrong reward rate currently cannot be fixed without an App Store release, and offers change weekly.
- **Cost of not doing it:** data goes stale between releases — the one thing that destroys trust in a card app. Plus every Android feature gets rebuilt from scratch.

### P2 — Analytics baseline

Minimal event logger (content refresh success/failure, version applied, screen views) posting to the P1 backend.

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

## 4. Visa API assessment

| API | Verdict |
|---|---|
| **VMORC** (Merchant Offers) | ❌ Restricted to Merchants and contractually-bound service providers of Visa Members |
| **Visa Offers Platform** (card-linked offers) | ❌ Needs issuer partnership + enrolled cardholder PANs |
| **Visa Digital Benefits Platform** | ❌ Issuer-only |
| **Merchant Search / Locator** | ✅ Obtainable, and genuinely valuable — returns MCC |

MCC is the ground truth that the 60 prefix + 104 contains patterns in `Resources/json/merchants/SeedDataGenericMappings.json` are hand-approximating today. "We know how this merchant actually codes" is a defensible accuracy claim.

**Constraint:** Visa APIs use mutual TLS with a Visa-issued PKI certificate, which cannot ship in an iOS binary. Any Visa integration requires a server-side proxy — so it follows P1, and only Merchant Search/Locator belongs on the roadmap.

## 5. Market sequencing

US / English first, then HK, TW, AU, UK, CA.

Current data skew to close before expanding:

| Region | Cards | Notes |
|---|---|---|
| US | 157 | Deep — 268 benefits, all recommendation content |
| HK | 15 | Rewards JSON exists for Citibank, Hang Seng, HSBC, Standard Chartered |
| CA | 3 | Amex only |

Recommendation content is US-only *and* all `isActive: false`, so the engine returns nothing in every market today.

Localization already covers `en`, `zh-Hans`, `zh-Hant-HK`, `zh-Hant-TW` for model content — see `LOCALIZATION_REFERENCE.md`. UI chrome is only registered for `en` / `zh-Hant-HK`.

## 6. Open questions

- **Hosting / authoring layer.** Current recommendation: Supabase (Postgres + table editor for authoring) with a publish step exporting to static JSON bundles on a CDN (Cloudflare R2 for zero egress). Explicitly **not** Sanity. Start against a plain bucket populated by a script from the repo JSON; add the authoring UI once the pipeline is proven.
- **Monetization posture.** Affiliate (`CardRecommendation.affiliateURL` already exists), subscription, or neither. Undecided.
- **No test target exists.** At minimum, P1's validation/rejection paths and P3's value calculator need coverage — those are where a silent bug either bricks content or misstates money.
