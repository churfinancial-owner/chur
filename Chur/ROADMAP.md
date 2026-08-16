# Chur Roadmap

Growth priorities and the reasoning behind them. **Update whenever priorities shift or a phase completes.**

Last reviewed: 2026-08-15.

**Where the numbers stand right now:** app `1.0 (1)`, live content **v29**, 18 domains, 175 cards / 272 benefits / 192 hand-authored categories / 171 card images / 151 icons. Verify with `swift run ChurContentPublish --verify` rather than trusting this line — it is a snapshot, and the version moves every publish.

**State at the end of the 2026-08-15 session.** P0, P1a, P1b and P1d are done; the remote content pipeline is complete — every domain but `SeedDataRegions` publishes, and no artwork ships in the binary. P1c's **test vectors are done and green** (33 cases, and the project's first test target); its written JSON contract stays deferred until Android is real. The **online cross-border FX fix** shipped in the P1d publish.

**P1d is done, published and running.** 18 domains live, all icon art on the CDN, the merchant FX correction shipped alongside it. Authored on a machine with no Swift toolchain and compiled on the Mac afterwards; the gap cost one duplicate-id error and one emoji sizing bug, both real defects the change surfaced rather than caused.

**Carried into the next session:**

1. ~~Commit `art-uploaded.json`.~~ Done — all 322 keys recorded, regenerated from the art files rather than copied, since content-addressed keys make the file a pure function of the bytes on disk.
2. **Publish `paze_10`.** The benefit is committed but live content has 272 benefits, not 273 — so the perk does not exist on any device, including the simulator, because remote content outranks the bundle. One `--upload`.
3. **22 icon names still have no artwork.** Two kinds, and they want opposite treatment: real brands worth sourcing a logo for (`icon_home_depot`, `icon_lowes`, `icon_sams_club`, `icon_tmall`, and the HK/regional issuers), and abstract concepts that probably never had art and should lose the `iconName` instead (`icon_mobile_pay`, `icon_wallet_topup`, `icon_foreign_transactions`, `5k_pv_purchases`). Both the publisher and `SeedDataValidator` list them every run.
4. ~~Collapse the icon coverage report~~, ~~spot-check art in `--verify`~~, ~~teach the coverage checker about Swift-literal icon names~~, ~~delete the boilerplate test~~ — all done 2026-08-15.
5. ~~Decide the US-only merchants.~~ Done 2026-08-15 — all 78 now declare `businessRegion` or `globalBilling`. Shipped in the P1d publish.

The day's fixes are worth a skim before touching content code: publishing, card art and the onboarding first-run path each broke in ways that were invisible from the symptom. See "P1b — lessons worth keeping".

---

## 1. Where Chur stands today

| | |
|---|---|
| **What it does** | Per-dollar, point-of-sale ranker — "which card should I use at this merchant, right now" |
| **Data** | 175 cards, 272 benefit templates, 223 categories (192 hand-authored + 31 merchant-derived), 78 merchants, 171 card images, 151 icons — ~500 JSON files in `Resources/json/`, bundled as the offline baseline. All artwork lives at repo-root `CardArt/` and `IconArt/`, outside the app target. **Everything publishes remotely except `SeedDataRegions.json`** (P1a, P1b, P1d) — 18 domains. No artwork ships in the binary at all |
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

Domains live: **cards, rewards, benefits, merchants, merchantMappings, cardArt** (all but the first two added in P1b), plus the twelve added in P1d. JSON payload is ~440 KB total (~60 KB gzipped), plus ~17 MB of card images fetched individually and cached — far smaller than the 1 MB on disk, since per-file overhead and whitespace dominated.

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
3. ~~**Card art to the CDN**~~ — ✅ DONE (2026-08-13). `Assets.xcassets/Cards` deleted: 364 files, 19 MB, about two thirds of the asset catalog. **The built app went from ~59 MB to ~40 MB** — the full raw total, because PNG and JPEG are already compressed and the asset catalog had nothing left to squeeze. Measured on a local build, so treat it as the relative saving rather than the shipping figure; the App Store download size only exists once a build is uploaded. Art publishes as content-addressed images (`art/<imageName>-<sha8>.<ext>`) with a `cardArt` index domain; `CardArtLoader` resolves memory → disk → CDN, sha256-verified, and every render site goes through one `CardArtView` — 18 converted here, **five missed and found only by browsing the app on 2026-08-14** (`YearDetailSheet`, `GroupingDetailSheet_Components`, `ExpiringSoonHomeSection`, `CouponingView`, `RecommendedCardView`), now 23 and grep-verified. The user's own cards are prefetched so a wallet never depends on a live connection; the accepted cost is that a fresh install with no network shows placeholders for cards the user doesn't own. A **new card now ships without a release, artwork included** — the last of the three Android preconditions in §5b.
4. ~~**User-facing version line**~~ — ✅ DONE (2026-08-13), scoped down from what this list originally said. `Chur 1.0 (1) · content v17` in the Settings footer, for support rather than for users. The manual refresh button was deliberately *not* shipped: refresh is automatic, and a button in Settings saying "try again" advertises that the automatic path isn't trusted. Pull-to-refresh on the wallet covers the real need — see below.
5. ~~**Payload validation before publishing**~~ — ✅ DONE (2026-08-14). `SeedDataValidator` already checked card→benefit references on device, which is what surfaced the ten silently-dropped benefits. The missing half was the publisher, and scoping it corrected the diagnosis: the two sides do **not** disagree on rules — the publisher is stricter than the app on four of six domains. It simply never looked at its own *output*. `loadCardArt()` returning an empty array was a legitimate `[CardArt]`, it reduced into `{}`, and nothing examined the assembled bytes. `validatePayload` now runs inside `write(_:domain:version:to:)`, before the file reaches `dist/`, applying the app's rules to exactly what would be uploaded. Verified against all six real payloads and ten regressions, including the empty index itself. A domain with no rule is an error rather than a pass, so the next `ContentDomain` cannot be added unvalidated.

   `--verify` ships with it, answering the other question: not "is my candidate sound" but "is production broken right now". It fetches the live manifest, checksums every bundle and validates it with the same rules — the check that would have caught contentVersion 16 in two seconds instead of hours. Read-only and runnable from any directory.

**Deliberately not done: one shared rule set in a Swift package.** It would protect against drift that does not exist yet, costs a local SPM package plus an Xcode project change, and would be superseded — Android needs these same rules and cannot import Swift. The single source of truth belongs in P1c's JSON contract spec, with each platform's validator checked against it. Until then the two implementations name each other in comments.

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
- **Deleting the data left the tool that reads it pointing at a hole.** Removing `Assets.xcassets/Cards` was the correct end state, but `ChurContentPublish` still built its art index from that path. It found zero images, published `cardArt-16.json` as `{}`, and uploaded it. Nothing failed: the script printed a `✅`. The blast radius was the whole pipeline, because staging is all-or-nothing — one rejected domain discards cards, rewards, benefits, merchants and mappings with it, so "the card art is broken" was actually "no remote content applies at all". **When you delete something, grep for what reads it, including tooling outside the app target.** The images are now at repo-root `CardArt/`, deliberately outside the Xcode synchronized folder, and the publisher refuses to emit an empty index rather than shipping one.
- **The publisher and the app validate the same payload by different rules.** The app rejected the empty index correctly; the script that produced it had no opinion. Two validators that disagree means the strict one only ever fires on a device, which is the most expensive place to find out. This is the argument for P1b item 5 below, promoted from housekeeping to the next thing worth doing.
- **`try?` plus `URL` equality standing in for file identity deleted the cache on every write.** `pruneOldVersions` removed stale hashes of an image and kept the current one by comparing `URL`s — but the URL from `contentsOfDirectory` and the one built by `appendingPathComponent` can differ in representation while naming the same file. When they did, the prune deleted the image it had just cached. Art still displayed (the in-memory `NSCache` had it), the disk cache read a flat zero, and every launch re-downloaded everything. Two silent `try?`s meant nothing was logged. Compare filenames, not URLs, and never let a cache failure be silent. The same four lines held a second bug: matching stale copies with `hasPrefix("\(imageName)-")` also matched *other cards* — `amex-gold` deleted `amex-gold-business`, and 25 of the 171 names are a prefix of another, so paired cards evicted each other indefinitely.
- **"All N call sites now go through X" is a claim, not a fact, unless something checks it.** Item 3 below said all 18 render sites used `CardArtView`. Five did not, and they rendered blank for weeks — including the month summary, whose *header* was converted while its rows were not, so it looked half-working rather than broken. A grep at the time would have taken one command. Written down, an unverified count becomes the thing the next session trusts instead of re-checking.
- **The first-run path is a different app, and nothing exercises it.** The content refresh lived in `ContentView.task`, and `RootView` shows `ContentView` *instead of* onboarding — so a brand-new install ran no refresh at all until onboarding finished. Every new user picked their cards from a list with 175 grey rectangles. Invisible in development forever, because a developer's simulator has already onboarded. Delete the app and walk the first run before calling a content feature done.
- **`value: Int` can't hold $12.95.** Widening it to `Double` touches `BenefitTemplate` *and* the `Benefit` `@Model`, so it's a schema migration — deferred to P3, where the spend-profile migration already has to happen. Rounded to 13 meanwhile, overstating by $0.60/year. Worth doing properly when P3 opens the schema anyway.

**Hand-authored categories were excluded from P1b — closed in P1d, which published them.** The note below is why it waited, and it is still the reason to be careful when editing them.

**Hand-authored categories are still excluded from P1b — but the reason has changed.** The blocking question was the rule, and the rule now exists and is enforced (above), so what remains is only plumbing: an aggregation for `categories/*.json`, a `ContentDomain` case, and a branch in `SeedDataLoader.loadCategoryTemplates()`. The 31 merchant-derived categories already publish this way.

What still deserves care before doing it: hand-authored categories carry `cardFilter`, `excludeFromParent` and `categoryLinks`, which feed `CardRateCalculator`'s match resolution. A bad publish there changes *prices* rather than labels — a different blast radius from anything published so far, and the reason it should follow the P1c test vectors rather than precede them.

#### P1c — half done (2026-08-14)

Written JSON contract spec + shared pricing-engine test vectors (see §5 Android).

**Test vectors: done. Contract spec: still deferred**, because Android is not happening soon (Pak Ho, 2026-08-14). The roadmap's standing advice was to write both on the iOS timeline regardless; that advice was right *for the test vectors* — they capture what the engine does today, while there is only one engine and the expected values can be read off it. After a Kotlin port exists the same work becomes adjudicating which of two disagreeing engines is correct, case by case.

Split accordingly:

- ~~**Pricing-engine test vectors**~~ — ✅ DONE (2026-08-14, extended 2026-08-15). 33 cases in `ChurTests/pricing-engine.json`, run by `ChurTests/PricingEngineVectorTests.swift` — the first regression test `CardRateCalculator` has ever had, and the first test target the project has ever had. Covers every branch reachable from `computeAllMatchingRewards`: the seven-tier `matchWeight` ladder, payment-method gating, both channel checks, `reward.countries` and its `card.country` fallback, FX/`forceCrossBorder`/`acceptedRegions`, both overlays, zero-rate suppression, `cardFilter`, boosts, and the output-shape rules (name dedupe, plan selection, alphabetical tie-break). The fixture is JSON rather than Swift precisely so the Kotlin port runs the identical file. See `PRICING_VECTORS_REFERENCE.md`.

  **Verified 2026-08-14** on a simulator: 32/32 green (31 vectors + the fixture-integrity test). The engine agreed with every expectation on the first run that got far enough to execute — no engine bug surfaced, which is itself the result: `CardRateCalculator` behaves as `MERCHANT_SETUP_REFERENCE.md` and its own comments describe. From here the vectors are the tripwire, not the audit. Two more were added on 2026-08-15 alongside the FX fix below.
- **The written JSON contract — genuinely only pays off with a second client.** Worth writing when Android becomes real, and not before.

**Lessons worth keeping**

- **The fixture had to be JSON, not Swift literals.** Swift fixtures would have been faster to write and worth nothing to Android — which is the entire reason this work was scheduled before the port rather than after.
- **`Date.current()` reaches into the engine through `RewardRate.isActive()`,** which the calculator calls with no argument. Any test touching a date-bounded reward is time-dependent unless it pins the mock, which also forces the suite to be serialized. Worth knowing before writing the second test suite.
- **`CardRateCalculator.rate` is stored and never read.** Found by tracing inputs for the runner. Harmless, but it means every call site passes a number that does nothing.
- **The vectors were written by reading the engine, not by running it** (no Xcode in the authoring environment), then checked against an independent reimplementation of the matching logic before the first Xcode run. All 31 agreed there and all 31 agreed in Xcode. The cross-check was worth its cost: it can only catch arithmetic and ordering slips, not a misreading of the Swift, but those are the errors you make writing 31 expectations by hand.
- **Every failure between writing the vectors and running them was harness, not engine.** Four rounds: an access-level violation, a fixture unreadable from the simulator, an unwrap missed when a type went optional, and a git collision from editing the same file on two machines. Budget for that gap whenever code is authored somewhere it cannot be compiled.
- **A simulator test cannot read the host Mac's filesystem.** `#filePath` resolved to exactly the right path and still returned `ENOENT`. Fixtures must be read out of the test bundle. `ChurTests/` being a synchronized folder makes that free — a JSON dropped beside the runner joins the target with no Build Phases wiring, which is why the fixture lives there rather than in a neutral repo-root folder.

It also inherits one concrete job from P1b item 5: **the structural rules now exist twice** — `RemoteContentService.validate(_:for:)` and `ChurContentPublish.validatePayload` — and a third copy is coming when Android needs them. The spec is where they should be stated once, with each implementation checked against it rather than against each other. Small, and the reason a Swift-only shared module was deliberately not built.

### Fixed along the way — online cross-border FX (2026-08-15)

**Online merchants never applied a foreign-transaction fee, for any card, in any region.** Found by hand, browsing PARKnSHOP — an HK-only merchant — while holding US cards, and noticing the rate looked too good next to the map version of the same merchant.

`businessRegion` is the only source of the fee online: `toNearbyMerchant` turns it into `acceptedRegions`, and with that nil `isCrossBorderSpend` returns false for every card. **No merchant had the field — 0 of 77.** The plumbing was complete end to end and nothing was ever authored into it. The map path was unaffected because MapKit supplies a real placemark country.

| Piece | Where |
|---|---|
| The data | `businessRegion` on the 35 merchants whose `featured`/`popular` name a non-US market, sourced from those lists |
| The decoupling | `OnlineMerchantDatabase.isAvailable` no longer reads `businessRegion` |
| The guard | `SeedDataValidator` warns when a region-scoped merchant has no `businessRegion` |
| The pins | Two vectors: FX applied outside `acceptedRegions`, no FX when a merchant is global |
| The recipe | `MERCHANT_SETUP_REFERENCE.md` § Key fields |

**Lessons worth keeping**

- **A field that is plumbed but never authored looks exactly like a working feature.** Every layer existed — model, decode, conversion, engine branch, even a doc row — and the behaviour was simply absent. Grep found the field in five files and all five were correct. The only thing that would have caught it is asking what value the data actually holds, which is a different question from whether the code reads it.
- **The wrong answer was the higher number.** An FX fee makes a rate worse, so the bug always erred toward flattering the card. Failures that look like good news get reported late, if at all — this one survived until someone went looking at a merchant they couldn't shop at.
- **One field meaning two things is a trap that springs on the fix, not on the bug.** `businessRegion` drove both the FX fee and search visibility, so authoring it to fix the fee would have deleted 35 merchants from search — turning "wrong rate" into "merchant is gone". It was invisible beforehand precisely because the field was empty, which made the visibility check a no-op. Before filling in an unused field, grep for every reader, not just the one you came for.
- **`SeedDataValidator` validates the CDN, not your files.** It reads `MerchantSeedDatabase.seed`, which prefers remote content — so after a publish it reports on what is live, and a local fix appears to do nothing. Six rounds of "still seeing the same errors" came from reading its output as a verdict on the working copy. The tell is which errors *change*: when the bundled-file error cleared and the remote one didn't, the pull had obviously landed and the cache was the thing lying. **Clear Content Cache before trusting any validator output after a publish.**
- **"Always `git pull` before you publish" now has two data points.** P1b lost a session to publishing from a checkout that missed a fix; this session published merchant data that had a typo already fixed on GitHub, which then outranked the corrected local copy on the next launch. The rule is the first line of `CONTENT_PUBLISHING_REFERENCE.md` for a reason.
- **One malformed entry costs the whole file.** Three map rules used `prefix` where `containsMatches` takes `keyword`, and the decode failure took *every* generic map rule with it — the app kept working, just worse at recognising places. Per-file decoding is the right granularity for benefits (losing one perk beats losing all) and the wrong granularity here, where one file is the entire ruleset.
- **The vectors did not catch this and could not have.** `accepted-regions-suppresses-fx` was green throughout; the engine was right all along. Engine tests pin behaviour given data — they say nothing about whether the data exists. The check that would have caught it is a seed-data assertion, which is what was added.

### P1d — ✅ Content pipeline finished (2026-08-15)

Filled in at last, after two sessions of sitting empty. The items were **the rest of the seed data, plus the rest of the art** — everything `Resources/json/` and `Assets.xcassets` still held that a release was required to change.

**Published and verified 2026-08-15.** 18 domains live (up from 6), 151 icons on the CDN, asset catalog down from 10.4 MB to 1.1 MB. The 33 pricing vectors stayed green throughout, which is what says the three rate-bearing domains — categories, boost programs, reward programs — went remote without moving a number.

**The two halves are bought with different currencies, and conflating them is how the reasoning goes wrong.**

| | JSON → CDN | Art → CDN |
|---|---|---|
| **Buys** | Fixing data without an App Store release | Adding a partner/issuer without a release |
| **Saves in app size** | **Nothing.** The architectural invariant keeps bundled JSON permanently as the offline fallback | 1.9 MB, after the one oversized file below |
| **Costs** | One `ContentDomain`, one loader branch, two validation rules | A render-path conversion at every call site, and a fallback that hides its own failure |

The size argument that justified card art (19 MB, two thirds of the asset catalog) **does not transfer.** All 151 icons together are 1.9 MB once `icon_disneyplus` is fixed — under 5% of a 40 MB app. Icon art moves for publishing cadence and for nothing else; recorded here so a future session doesn't re-derive it as a footprint win and get the tradeoff wrong.

#### What goes remote

| Domain | Files | Blast radius | Verdict |
|---|---|---|---|
| `recommendations` | 6 | None — read-only structs, nothing persisted, `isActive: false` throughout | **Yes, first.** The safest domain there is, and SUB offers are the fastest-staling content in the app |
| `badges`, `partners`, `transferPartners`, `autoRentalCoverage`, `cellPhoneProtection` | 5 | Read-only. `detectionRules` reference benefit ids → cards↔benefits-style cross-domain agreement | Yes |
| `issuers`, `programUpgrades` | 2 | Display only | Yes |
| `programs` | 1 | **Money math** — `pointCashValue` | Yes, and it is already half-broken (below) |
| `boostPrograms` | 1 | **Rates** — `CreditCard.boostMultiplier` → `CardRateCalculator:245` | Yes, with a vector run |
| `categories` | 14 | **Prices** — `cardFilter`, `excludeFromParent`, `categoryLinks` | Yes, last |
| `iconArt` | 151 images | A blank chip or a silent emoji fallback | Yes — for cadence, not bytes |
| ~~`SeedDataRegions`~~ | 1 | Gates onboarding and locale resolution | **No — stays bundle-only.** It changes approximately never, and a bad payload strands a user with no region to pick. Nothing is gained by making it mutable |

`SeedDataRegions` being an explicit *no* is the part worth keeping. "Publish everything" is not the goal; publishing is for data that changes faster than releases do.

#### Three things found while scoping it

1. **`SeedDataPrograms` is already half-remote, and wrong because of it.** `CardDatabase.swift:303` reads it from the bundle while resolving *remote* cards, so a card published with a reward program the build has never seen gets no `pointCashValue`. The coupling was created the day cards went remote in P1a and has been latent since.

2. **25 icon names referenced in JSON have no imageset**, and every render site falls back to an emoji or an empty chip — so nothing looks broken. Six are near-miss typos with the art sitting right there unused (`icon_allegiant`/`icon_allegient`, `icon_carousell`/`icon_carousel`, `icon_taobao`/`icon.taobao`); the other 11 are genuine gaps, almost all issuer logos in `control/`. Exactly the class of the five missed `CardArtView` call sites, but harder to see: a grey rectangle reads as broken, an emoji reads as intentional.

3. **One file was 68% of all icon art.** `icon_disneyplus.png` shipped at **2787×2807, 5.9 MB**, rendered at ~40pt, against neighbours of 7–35 KB. Resizing it recovers more than moving every other icon to the CDN would. Found by sorting the asset catalog by file size, which had never been done — worth doing after any bulk art import.

#### The two questions this section was supposed to answer

1. **Is a build going to anyone other than Pak Ho soon?** Still no. P2a stays behind this section — but the moment that changes, it jumps the queue, because instrumentation added after launch says nothing about launch.
2. **Does any item need a schema change?** **No.** Every domain here is read-only or already-persisted shape; nothing new lands on a `@Model`. P1d and P3 stay independent, and the first real staged migration is still the spend profile.

#### P1d — lessons worth keeping

- **Moving art to the CDN exercises every fallback path for the first time.** `MerchantIconView`'s emoji fallback was fixed at 80pt — right for the popup watermark it was written for, wrong for the 56×36 search row that also uses it. It had been wrong since the day it was written and nobody could see it, because bundled art meant the fallback almost never rendered. Publishing art doesn't only risk the *loading* path; it promotes every *fallback* to a path users actually see. If a shared view has a fallback sized, coloured or laid out for one call site, this is the release it surfaces in.
- **A view that resolves to `EmptyView` does not run its `.task`.** `IconArtView`'s no-fallback initialiser used `EmptyView`, which produces no render nodes — so the modifier attached to it never fired and those call sites could never *start* a download. They rendered only icons some other screen had already cached. It presented as a random subset (every badge, every alliance logo, and issuer logos except the few that double as category `iconName`s) and survived four rounds of diagnosis, because every layer the symptom pointed at was provably fine: files present, hashes matching the bucket, all URLs returning 200, bundles verifying. **The fallback is `Color.clear` — invisible, exactly the caller's frame, and a real view.** `CardArtView` was never affected because its placeholder is always a real view, which is the only reason P1b did not find this first.
- **An image adapts to its frame; a `Text` ignores it.** The specific mechanism behind the above, and worth knowing before writing the next one: `.scaledToFit()` makes art fit whatever frame the caller gives it, so an icon path needs no size parameter. A `Text` renders at its font size regardless of frame, so the fallback cannot inherit what the image got for free. Any placeholder built from text needs its size to travel with the call site.
- **Aggregating the data is a free audit of it — three for three.** A duplicate `material_hardware` category, byte-identical, in one file. Invisible on device forever: `CategorySyncService` builds `templateByID` with `uniquingKeysWith: { first, _ in first }`, so the second entry collapsed into the first and no duplicate row was ever inserted. That is now the third latent data bug publishing has forced into the open (`marriott_gold_status`, the `target` map pattern, this). It is no longer a coincidence — expect one every time a domain joins the pipeline, and treat a clean first run as the surprise.
- **`static let` is the wrong shape for anything publishable.** `BoostProgramDatabase.all`, `ProgramUpgradeDatabase.all` and `RewardProgramDefaults.all` were all `static let` — resolved once on first access, so a refresh landing mid-session could never reach them. Two of the three are money. Nothing would have reported it; the version moves, the log says `applied`, and the numbers stay put until relaunch. **Every domain also needs a line in `ContentRefreshCoordinator.reloadDatabases()`**, which is the same failure from the other end.
- **Two lists that must agree need a guard, not a convention.** The publisher's `allDomains` exists so `--verify` can report an unpublished domain, and it is only useful if it matches what was actually written. That is an assertion, not a comment — added, because a list maintained by discipline rots the first time someone adds a domain in a hurry.
- **Sort the asset catalog by file size after any bulk import.** `icon_disneyplus` shipped at 2787×2807 / 5.9 MB, rendered at ~40pt: 68% of all icon art, against neighbours of 7–35 KB. It had never been looked at because nothing surfaces it — the app renders it fine, the build succeeds, and the catalog compresses nothing. One `find -printf '%s'` sorted by size found it in seconds.
- **"I fixed it locally" is not a state the repo can see, and the publisher reads the repo.** The oversized PNG was reported fixed and was unchanged in the working copy, on `origin/main`, and on the branch — the edit had never been saved. Caught only because the publish printed `iconArt: 7.6 MB` where 1.9 was expected. This is the third instance of the family the publishing reference opens with: **the byte counts in the publish output are the check, not your memory of what you changed.**
- **The publisher believed its own success three times in one session.** An empty `cardArt` index in P1b, a `cardArt-26.json` that reported uploaded and 404d, and 55 Finder duplicates (`icon_delta 2.png`) that passed the duplicate check because they are genuinely different imageNames. Each printed a tick. `--verify` could have caught all three and was something you had to remember to run, about failures you had no reason to suspect — so `--upload` now runs it on itself, and publishing and confirming are one action the way publishing and committing are. **A tool that only validates its inputs will keep reporting success while being wrong;** what it also has to check is that the world matches what it thinks it did.
- **`git pull origin <branch>` does not put you on that branch.** It merges the branch into whatever you have checked out — so a session of work landed on local `main`, and the subsequent push failed with `src refspec does not match any`. Nothing was lost, but local `main` silently carried unmerged PR work, one `git push origin main` away from bypassing review. `git branch --show-current` before publishing or pushing, every time.

### P1e — Minor UI enhancements · **to be filled in**

Opened 2026-08-16, ahead of P2. Small visual and interaction polish, captured here so it is a phase rather than a pile of one-off tweaks.

**Fill this in at the top of the next session, before any code.** P1d spent two sessions empty for want of five minutes of writing down, and the note that says so is three sections up.

Three things worth deciding as the list is written, because each changes what the work touches:

1. **Does it need a new colour or font?** Both sets are meant to be reused, and `fonts.swift` is explicitly called out in `CLAUDE.md` as having grown too large. A UI phase is where that pressure lands, so decide per item whether an existing `chur*` value fits before adding one.
2. **Does it touch a string?** UI chrome strings belong in `Localizable.xcstrings`, migrated incrementally as views are touched rather than in a bulk rewrite. A UI pass is the natural moment — see `LOCALIZATION_REFERENCE.md` for the recipe and the progress table.
3. **Does it touch an art render path?** Every one now goes through `CardArtView` or `IconArtView`. P1d's costliest bug was a fallback that had been wrong since the day it was written and only became visible once art moved to the CDN — so if an item changes what a placeholder looks like, check it against a cold cache, not just a warm one.

Two P1d findings sit squarely in this phase's territory and are worth folding in:

- **22 icon names still resolve to nothing**, listed on every publish. The abstract ones (`icon_mobile_pay`, `icon_wallet_topup`, `icon_foreign_transactions`, `5k_pv_purchases`) may be better served by deleting the `iconName` so the emoji is the intended rendering, rather than by sourcing art.
- **`CategoryIconView` is called at seven different sizes** with `.system(size:)` passed in at six of them, against the design-system rule. `MerchantIconView` was fixed this way in P1d; the same treatment fits here.

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

**c. ~~The pricing engine needs shared test vectors.~~** ✅ DONE (P1c, 2026-08-14). `ChurTests/pricing-engine.json` holds 31 `(cards, category, expected ranking)` cases covering `matchWeight` resolution, `excludeFromParent` stops, channel filters, cross-border FX subtraction and boost overlays. The Kotlin port runs the identical file — that is what keeps the two engines honest. Format documented in `PRICING_VECTORS_REFERENCE.md`.

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
- **Test coverage is one suite deep.** `ChurTests` now exists and covers the pricing engine (P1c). Still uncovered: P1's validation/rejection paths and P3's value calculator — the two places a silent bug either bricks content or misstates money.
- ~~**Should the US-only merchants declare `businessRegion: ["US"]`?**~~ Closed 2026-08-15 — done, split by the same rule as the rest. **All 78 merchants declare one or the other** (41 `businessRegion`, 37 `globalBilling`), so the validator's warning has no standing exceptions left and any future omission is unambiguous.

  The hotel chains are the interesting call: Pak Ho put all seven on `globalBilling`, reading a hotel booking as billed in the guest's own currency. That is the online path only — a card used *at* a property still gets FX from the MapKit region, so the physical case stays correct either way. Airbnb is deliberately still `["US"]`; revisit if that reads as inconsistent.
