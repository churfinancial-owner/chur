# Chur Roadmap

Growth priorities and the reasoning behind them. **Update whenever priorities shift or a phase completes.**

Last reviewed: 2026-08-13.

---

## 1. Where Chur stands today

| | |
|---|---|
| **What it does** | Per-dollar, point-of-sale ranker — "which card should I use at this merchant, right now" |
| **Data** | 175 cards, 267 benefit templates, 223 categories, 77 merchants, 171 card images — ~500 JSON files in `Resources/json/`, bundled as the offline baseline. **Cards, rewards, benefits, merchants and card art all publish remotely** (P1a, P1b). Card art no longer ships in the binary at all; hand-authored categories are the only bundle-only domain left |
| **Persistence** | On-device SwiftData (`ChurSchemaV2_0`, migration-ready) + Google Drive appDataFolder backup (`ChurBackup` v3) |
| **Backend** | No application server. Three outbound calls: Cloudflare R2 content (`Core/Content/`), Google Drive (`Core/Sync/CloudSyncManager.swift`), Sanity CMS (`Features/News/Service/NewsService.swift`) |
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

### P0 — ✅ DONE (2026-08-12) — SwiftData migration blocker

Every `ChurSchemaV1_10`…`ChurSchemaV1_14` enum listed the **same live `@Model` classes**, so a version snapshot was a *pointer* to the models rather than a *photograph* of them. Add a field and all five versions silently described the new shape at once, leaving SwiftData with nothing to migrate from. `App/ChurApp.swift` then `fatalError`d on launch with no recovery path — the delete-and-reinstall that had been the dev workaround becomes total data loss in the field.

| Piece | Where |
|---|---|
| Frozen baseline | `ChurSchemaV2_0` in `Core/Sync/ChurSchema.swift` — collapses the synthetic v1.10 … v1.14 ladder (nothing had shipped, so no store existed at those versions) |
| The recipe | `ChurSchema.swift` header — freeze the old shape as a nested `@Model` copy *before* editing the live one, then add the next version + stage |
| Drift guard | `Core/Sync/SchemaFingerprint.swift` — DEBUG assertion when a model changes without a version bump |
| Recovery net | `Core/Sync/ChurStoreRecovery.swift` — quarantines an unreadable store (moves, never deletes) and starts fresh; `StoreRecoveryNoticeView` explains it and points at Drive restore |
| Backup completeness | `ChurBackup.currentVersion = 3` — nine previously-dropped user values now survive a restore (DataDictionary audit notes 14–16) |

**Verified 2026-08-12** on a simulator, by deliberately corrupting `Chur.store` and relaunching: the failure was caught, the old store quarantined (moved, not deleted), the recovery notice shown instead of a crash, and the wallet restored from Google Drive afterwards. The fingerprint guard is recorded and silent on a matching schema.

**Still unproven:** no *real* staged migration has run yet, because no model has changed since. The first one — likely `User.spendProfile` for P3 — is the real test. Follow the header recipe; the fingerprint guard will stop you if you skip a step.

**Lessons worth keeping**

- **A `VersionedSchema` must be a photograph, not a pointer.** This is the whole bug in one line. `models: [CreditCard.self]` in five different enums is five pointers to one mutable thing.
- **The mistake was invisible to every tool.** It compiled, it ran, and the DEBUG workaround (delete the app) *looked* like normal schema-change friction rather than a defect. That's why the fix includes a tripwire and not just a correct baseline — being right once doesn't help if the next change silently un-fixes it.
- **Fake history is worse than no history.** Four of the five versions were authored in a single commit, describing stores that never existed. They looked like diligence and provided nothing. Delete synthetic versions rather than migrating through them.
- **A backup is only a safety net for the users who have one.** Sign-in is skippable and Apple Sign In has no backup at all, so store recovery is an empty start for those users. Worth remembering before treating "they can just restore" as an answer.
- **SwiftData matches on entity shape, not on the version number.** A v1.14 store opened cleanly under v2.0 because this work changed no model fields — the entities were byte-identical and there was nothing to migrate. Bumping a version identifier alone is not a migration and does not invalidate an existing store. This also meant the recovery path had to be tested by deliberately corrupting a store; it would never have fired on its own.
- **The recovery screen is insurance against your own future mistake, not against user behaviour.** The realistic triggers are a bad migration stage in a future release, a TestFlight downgrade, a kill mid-migration, or a full disk — in that order. If it ever starts appearing often, that is a release regression signalling itself, which makes it the single best candidate for the first P2 analytics event.
- **Auditing the backup found worse bugs than the one being fixed.** `autoApplyAmount` being dropped meant a restored benefit replayed the full period budget instead of the user's chosen amount — silently wrong money, and nothing to do with migration. Field-by-field DTO audits are cheap; do one whenever a model gains user-editable state.

### P1 — Remote content pipeline

CDN-hosted aggregated JSON bundles + a version manifest, with the bundled JSON retained permanently as offline fallback.

**Architectural invariant — do not break:** the app only ever reads static JSON from the CDN. It never queries a database or CMS directly. This is what keeps the authoring layer swappable, stops a vendor outage from breaking app launches, and lets Android consume the identical files.

- Client contract stays **the JSON shapes that already exist**, so the hosting choice stays swappable and a future Android app consumes the identical manifest — no second API.
- Propagation into user wallets is already built: `Core/Sync/CardSyncService.swift` → `syncWalletCards(modelContext:)` reconciles against updated templates and already protects user edits via the `hasCustom*` flags.
- Safety: reject any payload failing sha256 or decode, keep the previous cache, gate old clients with `minAppVersion`. A bad publish must never brick the app.

- **Why:** a wrong reward rate currently cannot be fixed without an App Store release, and offers change weekly.
- **Cost of not doing it:** data goes stale between releases — the one thing that destroys trust in a card app. Plus every Android feature gets rebuilt from scratch.

#### P1a — ✅ DONE (2026-08-11)

Live at `https://content.chur.app`. A reward-rate change was published and reached the simulator without an App Store build, then reverted the same way.

| Piece | Where |
|---|---|
| Publish script | `Scripts/ChurContentPublish` — `swift run ChurContentPublish [--upload]` |
| Hosting | Cloudflare R2 bucket `chur-content`, custom domain `content.chur.app` |
| Client | `Chur/Core/Content/` — `ContentDomain`, `ContentManifest`, `ContentStore`, `RemoteContentService` |
| Wiring | `CardDatabase.loadCachedCards()` prefers remote; refresh on launch/foreground in `ContentView`; version + manual refresh in the DEBUG hammer menu |
| Switch | `FeatureFlags.remoteContentEnabled` in `App/Config.swift` |

Domains live: **cards, rewards, benefits, merchants, merchantMappings, cardArt** (all but the first two added in P1b). JSON payload is ~440 KB total (~60 KB gzipped), plus ~15 MB of card images fetched individually and cached — far smaller than the 1 MB on disk, since per-file overhead and whitespace dominated.

**Operating rule: commit *and* publish.** The repo stays the source of truth; the CDN is a copy. Publishing without committing makes them drift, and the next run of the script republishes the old values.

#### P1a — lessons worth keeping

- **`manifest.json` is the only file that makes a version live.** Bundles are inert payload. A publish that uploads new bundles but not the manifest changes nothing, and the app is correct to ignore it. This cost real time — the bundles were re-uploaded three times while the stale manifest kept serving v1.
- **`cf-cache-status: DYNAMIC` means Cloudflare is *not* caching**, so CDN caching can be ruled out as a cause immediately. It was the first suspect and the wrong one. No cache rule is needed for R2 custom domains serving JSON.
- **Byte counts in the script output are a free diff.** A one-character rate edit (`5.0` → `10.0`) moved rewards from 118325 to 118326 bytes, which confirmed the edit landed before anything was uploaded.
- **`dist/` accumulating versions was the root cause** of the stale-manifest confusion. The script now clears it each run so it only ever holds the current three files.
- **Upload order matters:** bundles first, manifest last. A manifest pointing at bundles that failed to upload would fail every client's checksum check. Same reasoning as `RemoteContentService` staging all domains before committing any.
- **Old bundles should not be deleted from R2.** They're ~200 KB against a 10 GB free tier, and keeping them allows a rollback by republishing a manifest that points at an earlier version — no re-upload, no release.
- **App Groups need a paid Apple Developer account.** The entitlement shows red without one. `ContentStore.containerURL` falls back to Application Support, so P1a works regardless; this only blocks P4's widget sharing the cache.

#### P1b

Ordered by value-to-effort, not listed arbitrarily:

1. ~~**Benefits**~~ — ✅ DONE (2026-08-13). One `ContentDomain` case, one aggregation in the script, one branch in `BenefitDatabase.loadCachedBenefits()`, one validation case, exactly as predicted. Both refresh call sites now reload `BenefitDatabase` before `CardSyncService.syncWalletCards`, which reads it. **Verified 2026-08-13** to the same bar as P1a: 267 benefits load, the two Schwab tiers appear on the Amex Schwab Platinum, and after publishing all three domains the app refreshed from `content.chur.app` and kept showing them — proving the published payload agrees with the bundle rather than overriding it. This was the first publish where two domains had to agree with each other: remote cards now reference benefit ids that only exist in the benefits bundle, so a partial publish would make perks vanish rather than merely misstate a rate. See the lessons below — the plumbing was the easy half.
2. ~~**Merchants**~~ — ✅ DONE (2026-08-13). Shipped as **two** domains rather than one: `merchants` (77 entries) and `merchantMappings` (`SeedDataGenericMappings.json`), each falling back to its bundled JSON independently, so a broken mappings payload costs map name-matching instead of the merchant list that online search and brand categories both depend on. Verified on a simulator, including the mixed-version case where the manifest omits a domain the build knows about.
3. ~~**Card art to the CDN**~~ — ✅ DONE (2026-08-13). `Assets.xcassets/Cards` deleted: 364 files, 19 MB, about two thirds of the asset catalog. Art publishes as content-addressed images (`art/<imageName>-<sha8>.<ext>`) with a `cardArt` index domain; `CardArtLoader` resolves memory → disk → CDN, sha256-verified, and all 18 render sites go through one `CardArtView`. The user's own cards are prefetched so a wallet never depends on a live connection; the accepted cost is that a fresh install with no network shows placeholders for cards the user doesn't own. A **new card now ships without a release, artwork included** — the last of the three Android preconditions in §5b.
4. ~~**User-facing version line**~~ — ✅ DONE (2026-08-13), scoped down from what this list originally said. `Chur 1.0 (42) · content v9` in the Settings footer, for support rather than for users. The manual refresh button was deliberately *not* shipped: refresh is automatic, and a button in Settings saying "try again" advertises that the automatic path isn't trusted. Pull-to-refresh on the wallet covers the real need — see below.
5. **`Debug/Testing/SeedDataValidator.swift`** extended to validate a candidate payload before publishing. Partly done: it now checks every card's benefit references against what `BenefitDatabase` actually loaded, which is what surfaced the ten silently-dropped benefits. Validating a *candidate* payload before upload is still outstanding.

**Release-only gaps, found by asking "what does a user without the debug menu get?"** Both were invisible in development and neither had a workaround in a release build:

- **No way to ask for content.** Refresh ran on launch and foreground behind a 30-minute gate, so the only remedy was backgrounding the app — which nobody knows to do. The wallet now pulls to refresh, skipping the interval gate but not the version gate, and reports back in three states. A silent pull reads as broken.
- **No way to know why a refresh did nothing.** Rate-limited, unchanged, below `minAppVersion` and outright failed were equally silent, so "the rate is wrong" was unactionable. `ContentRefreshLog` keeps the last five outcomes with the failure reason. Local only — it answers *what happened on this device*, which is a different question from *how often this fails across devices* (P2a).
- `ContentRefreshCoordinator` now owns the apply sequence (reload caches → sync categories → sync wallet → prefetch art). It was duplicated across three call sites and had already drifted once.

**The rule that unblocked item 2 — load-bearing ids are permanent, and the publisher enforces it.**

`MerchantEntry.brandCategory` synthesizes `SpendingCategory` templates, so publishing merchants makes 31 of the 223 categories remotely mutable — the exact thing excluding categories was protecting. Working that through surfaced a worse instance of the same class: **`Benefit.usageHistory` cascades on delete**, so renaming a benefit id destroys the user's redemption history, and benefits went remote earlier the same day.

The resolution is one invariant across five namespaces (card ids, benefit ids, plan ids, configurable slots, category ids), enforced at the only choke point every remote change passes through:

| Piece | Where |
|---|---|
| The rule + what each namespace costs | `DataDictionary.md` § Load-bearing IDs |
| The registry | `Scripts/ChurContentPublish/id-lock.json` — 694 ids, append-only, committed |
| Enforcement | `ChurContentPublish` refuses to publish when an active id disappears. A rename trips it automatically, being an add plus a removal. **No override flag** |
| Retirement path | Keep the entry, hide it (`visibility: "hidden"` / `isActive: false`), move the id to `retired` |

`BrandCategorySpec.visibility` exists so that retirement path is actually available for merchant-derived categories — without it the rule would be unenforceable for exactly the 31 categories that prompted it.

Note the lock was seeded from data as it stood on 2026-08-13, so it forgives everything published before that, including the `schwab_appreciation_bonus` rename made hours earlier. It protects from that point forward, not retroactively.

#### P1b — lessons worth keeping

The remote plumbing took one commit. Everything below came from actually running it, and none of it was about the CDN.

- **Remote content silently outranks your local edits, and nothing says so.** Once any version is cached, editing `Resources/json/` and rebuilding changes nothing — `CardDatabase.reloadFromBundle()` re-reads the remote cache despite its name, and the only escape was `resetAllData()`, which wipes the wallet. This cost most of a session: the app kept showing a benefit id that had been renamed days earlier. Fixed with a non-destructive **Clear Content Cache** debug action. Any future domain that goes remote inherits this trap.
- **`try?` on a per-file decode is a silent data-loss bug.** `enumerateFolder` skips any file that doesn't match `_BenefitJSON`, so **ten** benefits — 3.7% of the catalog — had never loaded in any build. No crash, no log, just perks that quietly didn't exist. Two causes: a required `value` missing or fractional (`12.95` against `value: Int`), and `"description": null` against a non-optional `String`. A tolerant decode is right for a *field* (losing a sentence beats losing the benefit) and wrong for a *file* (which just hides the problem).
- **Publishing forces latent data problems into the open, which is a feature.** Two files claimed `marriott_gold_status`; on-device the winner depended on enumeration order, so the bug was invisible. Publishing would have frozen an arbitrary choice into every client, so the script now refuses to publish a duplicate id. Aggregating data is a free audit of it.
- **The diagnostic was worth more than the fix.** Three guesses at why a benefit wasn't showing (`benefitType`? `displayGroup`? sync?) all missed. Twenty lines in `SeedDataValidator` comparing card benefit references against what actually loaded named the real cause immediately — and surfaced the other seven broken files as a side effect. Reach for the check that turns a guess into a fact earlier than feels necessary.
- **Build the switch that simulates the irreversible change, before making it.** A DEBUG toggle that made the app ignore bundled art paid for itself within minutes: it exposed that nine imagesets hold `.jpeg`/`.jpg` while the publish script only globbed `.png`. Those nine had always rendered from the bundle, so nothing looked wrong — they would have turned blank the moment the assets were deleted, which is the step you can't undo. The toggle was deleted along with the assets; it had done its job.
- **A tool's blind spot becomes a "fact" about your data if you let it.** The same PNG-only scan made me report nine imagesets as *empty* and their cards as blank in every build. Neither was true. Checking what was actually in those folders would have taken one command; instead the tool's limitation got repeated as a finding.
- **Ask what a user without the debug menu gets.** Two release-only gaps surfaced only from that question: no way to request a refresh, and no way to know why one did nothing. A third — `CardArtLoader` caching its index for the whole session — was a genuine bug that DEBUG builds hid, because Clear Content Cache papered over it. Development tools mask exactly the failures that have no user-facing remedy.
- **Cache invalidation isn't the only cost of content-addressed names; accumulation is.** Hash-suffixed filenames remove invalidation entirely — but the old file stays on disk forever unless something deletes it, which would have quietly undone the 19 MB the deletion was meant to save. Noticed only because Pak Ho asked what happens when art is updated.
- **Work that outlives an interaction must not inherit its cancellation.** Three separate bugs, one cause. SwiftUI cancels a `.task` when its view disappears, and `.refreshable` cancels its task the moment the gesture ends — so the launch manifest download died mid-flight as `NSURLErrorCancelled (-999)`, and the status pill cleared itself in the frame it appeared, because `Task.sleep` in a cancelled task returns instantly rather than sleeping. Both looked like "it doesn't work" and neither was where the symptom pointed. Anything writing to a shared cache, or meant to stay on screen after a gesture, belongs in an unstructured `Task`. Related: log a cancellation as its own outcome, never as a failure, or ordinary navigation buries the failures that matter.
- **A computed property that asks the OS something is a per-frame cost.** `ContentStore.containerURL` and `CardArtStore.directoryURL` re-resolved the App Group container on every card image, every row, every scroll frame — and without the entitlement (which needs a paid account) each attempt fails *and* logs, which is where the "client is not entitled" flood came from. The answer can't change while the app runs; resolve it once. Console noise was the only symptom, and it was hiding the `-999` that mattered.
- **`value: Int` can't hold $12.95.** Widening it to `Double` touches `BenefitTemplate` *and* the `Benefit` `@Model`, so it's a schema migration — deferred to P3, where the spend-profile migration already has to happen. Rounded to 13 meanwhile, overstating by $0.60/year. Worth doing properly when P3 opens the schema anyway.

**Hand-authored categories are still excluded from P1b — but the reason has changed.** The blocking question was the rule, and the rule now exists and is enforced (above), so what remains is only plumbing: an aggregation for `categories/*.json`, a `ContentDomain` case, and a branch in `SeedDataLoader.loadCategoryTemplates()`. The 31 merchant-derived categories already publish this way.

What still deserves care before doing it: hand-authored categories carry `cardFilter`, `excludeFromParent` and `categoryLinks`, which feed `CardRateCalculator`'s match resolution. A bad publish there changes *prices* rather than labels — a different blast radius from anything published so far, and the reason it should follow the P1c test vectors rather than precede them.

#### P1c

Written JSON contract spec + shared pricing-engine test vectors (see §5 Android).

### P2 — Analytics baseline

Adopt **TelemetryDeck** (Swift-first, privacy-focused; re-check pricing at signup — the roadmap's original note was free to 100k signals/mo, €9 for funnels and retention). No IDFA and no cross-app tracking, so no App Tracking Transparency prompt — which matters more for a finance app than the analytics themselves.

Deliberately *not* a homegrown events table — that gives rows, not funnels, retention or cohorts, all of which would then have to be built by hand.

**Split in two, because the halves have opposite timing constraints.** Same SDK, one afternoon of setup, but conflating them is how the useful half gets missed.

#### P2a — Release health · trigger: the first build that goes to anyone who isn't Pak Ho

A tool for the developer, not for growth. Its value depends entirely on being present *before* users arrive: instrumentation added after launch says nothing about launch, which is the riskiest week there will ever be.

| Signal | Why it earns its place |
|---|---|
| `content.refresh.applied` + version | Confirms the pipeline works on real devices, not just a simulator |
| `content.refresh.failed` + reason bucket | Unobtainable any other way. Network, checksum and validation failures need opposite responses |
| `content.art.fetch_failed` | Art is 171 separate requests since P1b item 3; a bad key otherwise reads as "some cards look blank" |
| `store.recovery.triggered` | The P0 tripwire. If it climbs, a migration broke — the earliest possible warning of a bad release |
| `app.launch` + content version | The denominator. Without it, "12 failures" means nothing |

**Privacy stance — decided, not incidental: send nothing about the wallet.** No card ids, no issuer, no count. It is tempting because it would reveal which cards people own, but wallet composition is financial profile data, and a card app that quietly reports it is one screenshot from a bad thread. Failure diagnostics don't need it, and the "not linked to identity" privacy label is only truthful if this line holds.

Build notes: a thin `Analytics` wrapper so signal names live in one file and the SDK stays swappable, off in DEBUG, behind a `FeatureFlags` kill switch, with a Settings opt-out. Test on a real device — an SDK is one more thing that can fail at launch.

`ContentRefreshLog` (P1b) is the local counterpart and already covers the one-device case, which is why P2a is not urgent while the only tester is Pak Ho.

#### P2b — Product analytics · trigger: enough users for numbers to mean something

Screen views, funnels, retention, cohorts. This is what tells you whether P3 or P4 actually worked.

- **Why:** the app is currently blind to all usage.
- **Cost of not doing it:** every decision below this line is guesswork, and there's no way to tell whether P3 or P4 worked.

### P3 — Annual card value

Join `CreditCard.annualFee` + benefit budgets (`BenefitUsageAnalyzer_Balance.periodBudget()` / `budget(for:)`) + realized `BenefitUsageRecord.redeemedAmount` + `CardRateSummary.effectiveCashBackRate` + a new self-reported spend profile.

Outputs: per-card keep / review / downgrade verdict; wallet-level "left on the table" (unredeemed budget this period) and "misrouted spend" (you'd earn $Y more using card Z for groceries).

- Requires a new persisted field on `User` (spend profile) → will be the **first real staged migration**; follow the recipe in `ChurSchema.swift`.
- Also upgrades `CardRecommendationEngine.recommend()` from taste-based (`strategyPreferences` only) to spend-aware. Note its weights don't sum to 1 — issuer diversity is `0.5`, larger than strategy match at `0.45`, likely a typo to fix while there.
- Surfaces in `UserWalletSummaryView` and Card Info; the net-value number should also flow into `SharePostcardView` — it's the most shareable number in the category.

- **Why:** this is the moat. It uses the one asset competitors don't have.
- **Cost of not doing it:** Chur stays a "which card now" app, competing head-on with three funded incumbents on their strongest feature.

### P4 — Widget

Best-card-for-category (`AppIntent`-configurable) + expiring-benefit countdown driven by `Features/Benefit/Service/ExpiringBenefits.swift`.

- Needs a Widget Extension target, entitlements (none exist today), and moving `ModelConfiguration` to a `groupContainer` — which relocates the store file and needs a one-time migration. P0 unblocked this; note the store path is now built inside `ChurStoreRecovery.makeContainer()`, so the `groupContainer` change goes there.
- **Why:** `ReminderScheduler` already drives the retention loop; a widget gives it a home-screen surface.
- **Cost of not doing it:** lowest-stakes item here. Upside, not a gap.

## 4. Stack decisions

| Need | Choice | Status |
|---|---|---|
| Serving content bundles | Cloudflare R2 (`chur-content`) + `content.chur.app` | ✅ Live, $0 |
| Publishing | `swift run ChurContentPublish --upload` (wrangler via `npx`) | ✅ Live |
| Authoring | Repo JSON; add TinaCMS or Decap **only when** hand-editing hurts | Not needed yet |
| Analytics | TelemetryDeck | Not started (P2) |
| Server-side compute | None needed. Cloudflare Workers ($5/mo) if that changes | — |

`chur.app` DNS moved to Cloudflare (registrar: Namecheap). The root domain serves a GitHub Pages site and ImprovMX handles mail — both survived the nameserver change. Keep the R2 `r2.dev` subdomain disabled so content has exactly one public URL.

**Rejected:** Sanity (owner preference). Supabase — its edge over plain file hosting was server compute, an analytics sink, and a table editor; the first two are no longer needed, and the third partly evaporates because reward plans normalize into `jsonb` and render as raw JSON text anyway. Not worth $25/mo plus a week of schema modelling. Firebase (painful nested-document editing, fights bulk publish), Airtable (per-seat cost + API rate limits), self-hosted PocketBase (a VPS to operate).

**Visa APIs — dropped.** VMORC, Visa Offers Platform and the Digital Benefits Platform are all issuer- or merchant-gated. Merchant Search/Locator is obtainable and would give real MCC data (better than the hand-written prefix/contains patterns in `Resources/json/merchants/SeedDataGenericMappings.json`), but it needs mutual TLS and therefore a server. Revisit only if a server exists for other reasons.

## 5. Android

A second client is planned. Three things must be true of P1 or Android becomes a rewrite rather than a port.

**a. The JSON contract is the spec, not the Swift types.** `_CardJSON`, `_RewardStructure` and `BenefitTemplate` currently *define* the format by virtue of being what decodes it. Write the contract down (a versioned schema doc, or JSON Schema) so Android implements against a spec rather than reverse-engineering Swift. Silent drift here breaks one platform without failing a build.

**b. ~~Card art has to move to the CDN.~~** ✅ DONE (P1b item 3). Art publishes as content-addressed images with a `cardArt` index domain, and `Assets.xcassets/Cards` no longer exists. Android consumes the same index — `imageName → { url, sha256, bytes }` — and needs its own equivalent of `CardArtLoader` (memory → disk → network, sha256-verified) plus a placeholder. The bare `Image(name)` call sites that would have rendered blank are gone; every render path goes through `CardArtView`.

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
