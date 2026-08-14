# Pricing Vectors Reference

The shared test vectors for `Core/PricingEngine/CardRateCalculator.swift`. **Read before changing the engine, the fixture, or `matchWeight` resolution; update it whenever a rule or fixture field changes.**

- **Fixture:** `TestVectors/pricing-engine.json` (repo root)
- **Runner:** `ChurTests/PricingEngineVectorTests.swift`
- **Roadmap:** P1c — the half that earns its place on iOS alone

---

## What this is for

`CardRateCalculator` decides which card a user is told to pull out. It had no test of any kind. A `matchWeight` edit, a new `excludeFromParent` on a merchant-derived category, or a rate change that silently reordered recommendations all shipped unnoticed — and since rewards publish remotely, some of those ship **without an App Store release**.

Two rules make the fixture worth more than an ordinary test file:

1. **The fixture is the spec, not the Swift.** When Android exists, the Kotlin port runs this same JSON. Anything expressed only in `PricingEngineVectorTests.swift` doesn't cross over — keep behaviour in the fixture and mechanics in the runner.
2. **A failing vector is a question, not a verdict.** It means the engine and the fixture disagree. Decide which one is wrong *before* editing either. Changing the expectation to match new behaviour is sometimes right and is always a decision worth a commit message.

## Where things live, and why

`TestVectors/` sits at the **repo root, beside `CardArt/`** — deliberately outside `Chur/`. `Chur/` is a synchronized root group in the Xcode project, so a fixture placed there is compiled into the app and ships to users as dead weight.

**The fixture reaches the tests through ChurTests' Copy Bundle Resources**, added as a *reference* (not a copy), so there is still exactly one file on disk. This is project configuration, so a fresh clone or a rebuilt test target needs it re-added:

> ChurTests target → **Build Phases** → **Copy Bundle Resources** → **+** → **Add Other…** → select `TestVectors/pricing-engine.json` → **Reference files in place**.

The runner also keeps a `#filePath` fallback that walks up to the repo root, but **that path does not work from a simulator** — tests run inside the simulator's filesystem and cannot read the host Mac. The fallback exists for a future host-side runner (a SwiftPM target, or a macOS destination); on iOS the bundle copy is the only path that works. `fixtureLoads` prints both locations it tried when neither resolves.

```
chur/
├── CardArt/                        ← card images (not in the app target)
├── TestVectors/
│   └── pricing-engine.json         ← the spec
├── ChurTests/
│   └── PricingEngineVectorTests.swift
└── Chur/
```

## Fixture format

```jsonc
{
  "formatVersion": 1,
  "categories": [ /* one shared category graph, used by every vector */ ],
  "vectors":    [ /* the cases */ ]
}
```

### `categories[]`

One graph shared by all vectors, so a vector never has to restate the tree. Every field maps straight onto `SpendingCategory`.

| Field | Default | Notes |
|---|---|---|
| `id` | required | Matching is by **string id** — a reward category that names no `SpendingCategory` still matches (`everything`, the overlay ids) |
| `name` | required | Fills all four localized name fields; display only |
| `level` | `null` | `parent` / `child` / `groupTarget` / `target` |
| `parentCategoryID` | `null` | Drives the ancestor chain in `matchWeight` step 5 |
| `categoryLinks` | `null` | Plain string ids. Matched directly (step 2) **and** folded in from every ancestor by `buildAncestorSets` |
| `excludeFromParent` | `false` | Blocks the ancestor cascade. `everything` still matches; payment methods still match, because step 3 runs first |
| `cardFilter` | `null` | Decoded by the app's own `CardFilter` type — `{networks, issuers, cardTypes, mode}` plus optional `regions` |
| `excludedPaymentMethods` | `null` | Payment methods the merchant can't take |
| `channels` | `null` | Restricts the *category*, checked by `isCategoryAllowedInChannel` — distinct from a reward's own `channels` |

### `vectors[]`

| Field | Notes |
|---|---|
| `id` | Unique, kebab-case. Shown in the test navigator and in every failure message |
| `rule` | Which engine rule this pins, in words. Printed on failure — write it for whoever is reading the red test, not for yourself |
| `input` | See below |
| `cards` | The wallet for this case |
| `expected` | `rankedCardSummaries` in order: `[{name, effectiveCashBackRate, rate?}]` |

**`input`**

| Field | Default | Notes |
|---|---|---|
| `categoryID` | required | Must exist in `categories[]` — the suite asserts this separately |
| `region` | `null` | Merchant region. `null` = global, which means **no FX for anyone** |
| `channel` | `null` | `in_store` / `online`. `online` also switches on the `online_transactions` overlay |
| `boostEnrollments` | `{}` | `programID → tierName`, e.g. `{"usbank-smartly": "50% Smartly Earning Bonus"}` |
| `allowPaymentMethodFallback` | `true` | |
| `forceCrossBorder` | `false` | |
| `acceptedPaymentMethods` | `null` | When set, payment-method rewards apply **only** for the listed ones |
| `acceptedRegions` | `null` | Overrides `region` for cross-border detection |
| `asOf` | `null` | ISO-8601. Pins `Date.current()` — see Determinism |

**`cards[]`** — `name` is the only required field. `id` defaults to a slug of the name, `issuer` `"Test Issuer"`, `network` `"Visa"`, `country` `"US"`, `cardType` `"personal"`, `status` `"active"`, `hasForeignTransactionFee` `false`. Supply either `rewards` (the legacy array) or `plans` (`{id, name, isDefault, rewards}`); `activeRewards` prefers the default plan when both exist.

**`rewards[]`** — `rate` required. `pointCashValue` defaults to `0.01`, so `rate: 5.0` means 5% unless stated otherwise. Also accepts `pointCashValueCurrency`, `rewardProgramName`, `categories`, `countries`, `channels`, `rewardStartDate`, `rewardEndDate`.

**`expected[]`** — order matters. `rate` is `CardRateSummary.rate` (the raw multiplier **after** boost) and is asserted only when present; state it on boost and overlay vectors, where it's the thing that proves the right reward was picked.

## Determinism

Three things would otherwise make the suite flaky, and each is handled:

- **`RewardRate.isActive()` reads `Date.current()`.** The engine calls it with no argument, so a date-bounded reward's answer depends on when you run the tests. Every date-sensitive vector sets `asOf`, and the runner pins `TestDataConfiguration.mockCurrentDate` around the call.
- **That mock is process-global**, so the suite is `.serialized`. Don't remove that without removing the mock.
- **`rankedCardSummaries` sorts ties alphabetically by name.** Expected rows are compared in order, so a tie must be written in alphabetical order or the vector fails for the wrong reason.

## What the vectors cover

Every branch reachable from `computeAllMatchingRewards`:

| Area | Vectors |
|---|---|
| `matchWeight` ladder | exact match, `categoryLinks` direct, payment-method fallback, `excludeFromParent` stop, single- and multi-hop parent chains, ancestor `categoryLinks`, `everything` fallback |
| Payment methods | survives `excludeFromParent`, blocked by `excludedPaymentMethods`, gated by `acceptedPaymentMethods`, disabled by `allowPaymentMethodFallback` |
| Channels | category-level (`isCategoryAllowedInChannel`) in both directions, reward-level `channels` |
| Geography | `reward.countries` mismatch, and the `card.country` fallback when `region` is `null` |
| Cross-border | FX fee reordering the ranking, `forceCrossBorder`, `acceptedRegions` suppressing FX |
| Overlays | `online_transactions` winning, an overlay-only reward ignored off-channel, `foreign_transactions` still netting the FX fee |
| Card-level | zero-rate suppression, cancelled cards, `cardFilter` include-mode |
| Valuation | boost multiplier scaling both rate and multiplier, point value outranking a higher multiplier |
| Output shape | duplicate card **names** collapsing, plan-based cards using the default plan, alphabetical tie-break |

## Adding a vector

1. Add the case to `vectors[]`. Reuse the shared category graph; only add a category if no existing one has the shape you need.
2. Write `rule` as a sentence naming the mechanism, not the symptom.
3. State the minimum: every unstated card and reward field takes a sane default, and a vector that only sets what it tests is readable years later.
4. Run the suite. If it fails, decide whether the engine or the expectation is wrong before touching either.

**Do not** add a vector that depends on the real seed data. A ranking over the shipping 175 cards is a different tool — it changes on every publish and belongs next to `ChurContentPublish --verify`, not here.

## Known couplings

Two things reach outside the fixture, and both are load-bearing:

- **`BoostProgramDatabase` reads `boost_programs.json` from `Bundle.main`.** The boost vector needs a real program id, a real tier name and a real eligible `templateID` (`us-bank-smartly` / `50% Smartly Earning Bonus`). If the host app isn't set, the lookup returns `nil`, the multiplier falls back to `1.0` and the vector fails — loudly, which is the right failure.
- **`RegionDatabase.normalizeRegionCode`** is pure and needs no bundle, but it folds `PR`/`VI`/`GU`/`AS`/`MP` into `US`. A vector using those codes is testing that folding, not cross-border logic.

One thing that looks like a coupling and isn't: `CardRateCalculator.rate` is stored on the struct and **never read** by the engine. The runner passes `1.0`. If a future change starts reading it, the fixture needs a field for it.
