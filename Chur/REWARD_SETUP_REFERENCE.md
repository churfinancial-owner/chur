# Reward Setup Reference (Cheatsheet)

How to author `Resources/json/rewards/*-rewards.json`. Companion docs:
- `MERCHANT_SETUP_REFERENCE.md` — how categories/merchants match (matchWeight, hierarchy).
- `../../DataDictionary.md` §4 — the full `RewardRate` model reference.

Every file maps **card template ID → reward structure**. Two structures are supported:

```jsonc
{
    "card-id-a": [ { ...reward }, { ...reward } ],          // simple: array of rewards (one implicit default plan)
    "card-id-b": { "plans": [ { ...plan } ] }               // plan-based: for cards whose structure changed over time
}
```

⚠️ **Strict JSON only — no trailing commas.** A syntax error makes the whole file silently fail to load (cards lose all their rewards with only a console `❌` log). Validate after editing:
`python3 -c "import json; json.load(open('chase-rewards.json'))"`

---

## Reward fields

| Field | Required | Notes |
|---|---|---|
| `rate` | ✅ | Multiplier: `3.0` = 3x/3%. Display hides a row that does not beat the card's own base — the lowest `everything` row, or 1.0 when it has none. It used to be a literal `1.0`, which hid every row on a miles card authored in miles per dollar, and would hide MMPower's 4% against its 0.4% base if it were still that way round. |
| `rewardProgramName` | ✅ | Must match a program in the programs seed so `pointCashValue`/currency resolve. |
| `pointCashValue` | — | Per-reward override; otherwise resolved from the program (default `0.01`). |
| `category` | — | Single category ID (legacy form). This is what the pricing engine matches. |
| `categories` | — | Array form — one reward matching several category IDs at the same rate. Preferred over `category` for multi-category. |
| `groupLabel` | — | Display-only group name (see Pattern 3). Never affects matching. |
| `merchantIdentifier` / `merchantName` | — | Merchant-specific rate (e.g. `"amazon"`). |
| `channels` | — | `["online"]`, `["in_store"]`, `["in_app"]` — restricts how the purchase is made. |
| `countries` | — | ISO codes where the rate applies (e.g. `["US"]`). |
| `excludedCountries` | — | ISO codes where the rate pays nothing (EEA carve-outs: `["FR", "DE", …]`). P1f. |
| `currencies` | — | Transaction currencies the rate applies to (`["JPY", "KRW", "THB"]`). Put a currency-scoped foreign bonus on `foreign_transactions`, not `everything`: the overlay only ever fires cross-border, and two `foreign_transactions` rows with different currency lists (designated 7x, other 5x) is the Travel+ shape. The currency is derived, never authored: a merchant operating in the card's own region (map region, or an online `businessRegion` that includes it) bills in the card's currency; a foreign merchant bills in its region's currency; a global merchant bills in the card's. P1f. |
| `paymentMethods` | — | How the purchase is paid: `mobile_pay`, `apple_pay`, `paypal_pay`, `contactless`, `unionpay_quickpass`, `alipay_hk`, `wechat_pay_hk`. Preferred over putting a payment id in `categories` (still works as a shim). Applies when the purchase *could* be paid that way — the merchant's accepted list, or a "Paying with" pick, narrows it. P1f. |
| `rewardStartDate` / `rewardEndDate` | — | ISO 8601 (`"2026-07-01T00:00:00Z"`). Expired rewards are hidden. |
| `isRotating` | — | Marks quarterly rotating categories; shows Rotating/Ends badges. Pair with start/end dates. |
| `gate` | — | What unlocks the rate: `{amount, currency, period, note}`. **Display only** — the app tracks no spend. P1f. |
| `cap` | — | Where the rate stops: `{amount, currency, period, kind, group, note}`. `kind` is `spend` (default) or `reward`; `group` names a shared pool so the row can say which bonuses drain it. **Display only.** P1f. |
| `rewardNotes` | — | Free prose under the row. Prefer `gate`/`cap` for caps and conditions — they render in all four languages. |
| `isUserConfigurable` / `configurableSlot` / `configurableOptions` | — | User-selectable slots only (see Pattern 4). |

If a reward has **no** `category`/`categories`, it matches **everything** (base rate).

---

## Pattern 1 — Plain category rate

```json
{ "rate": 3.0, "rewardProgramName": "Ultimate Rewards", "category": "dining" }
```

## Pattern 2 — One rate, several categories

```json
{ "rate": 4.0, "rewardProgramName": "Cash Back Rewards", "categories": ["public_transit", "ev_charging"] }
```
Displays one row **per category**. Use Pattern 3 if you want one labeled row instead.

## Pattern 3 — Group label (display-only)

Give one or more entries the same `groupLabel` (same rate, same program) and the UI collapses them into a single row titled with the label. Matching is untouched — each entry still matches its own category.

```json
{ "rate": 4.0, "rewardProgramName": "Cash Back Rewards", "category": "public_transit", "groupLabel": "Planet-Friendly" },
{ "rate": 4.0, "rewardProgramName": "Cash Back Rewards", "category": "ev_charging",   "groupLabel": "Planet-Friendly" }
```
→ shows once as "Planet-Friendly — 4%" (icon comes from the first category, after sorting by name).

Rules:
- Rows dedupe by **label + rate**. Same label at different rates = two rows (both showing the label).
- `rewardProgramName` is not part of the key — don't share a label across programs with different point values, or the effective-rate display will show only the surviving entry's value.
- English-only for now (same as configurable-slot labels).

## Pattern 4 — User-configurable slots ("choose your 4% category")

```json
{
    "rate": 4.0,
    "rewardProgramName": "Membership Rewards",
    "category": null,
    "isUserConfigurable": true,
    "configurableSlot": "4pct_slot_1",
    "configurableOptions": [
        { "label": "Restaurants", "includes": ["dining"] },
        { "label": "Utilities",   "includes": ["internet", "tv_cable"] }
    ]
}
```
- The reward matches **nothing** until the user picks a label; the picked label's `includes` become the reward's categories (`CreditCard.applySlotSelections()`).
- `configurableSlot` must be unique per card; the user's choice is stored per-slot in `slotSelections`.
- Multiple slots at the same rate get numbered pickers ("Choose your 1st/2nd 4% category").
- ⚠️ `configurableOptions` on a reward with `isUserConfigurable: false` is **dead data** — it does nothing. For fixed groups use Pattern 2 or 3 instead.

## Pattern 5 — Rotating quarterly categories

```json
{
    "rate": 5.0, "rewardProgramName": "Chase Cash Back Rewards",
    "category": "gas", "isRotating": true,
    "rewardStartDate": "2026-07-01T00:00:00Z", "rewardEndDate": "2026-09-30T23:59:59Z"
}
```
One entry per category per quarter. Expired entries hide automatically; future ones show dimmed with a "Starts" badge. Keep a non-rotating base-rate entry alongside.

## Pattern 6 — Plans (cards whose rewards changed over time)

```json
"chase-sapphire-reserve": {
    "plans": [{
        "planID": "chase-sapphire-reserve-2026",
        "planName": "Current Rewards",
        "isDefault": true,
        "isAvailableForNewUsers": true,
        "isPromo": false,
        "planStartDate": null, "planEndDate": null,
        "rewards": [ { ...reward }, ... ]
    }]
}
```
Use multiple plans for grandfathered vs. current structures; exactly one `isDefault: true`.

## Transfer handling fee

The charge a bank levies to move points to a partner, e.g. Citi HK's HK$200 per redemption. Authored once on the transfer program in `badges/SeedDataTransferPartners.json`:

```json
"fee": { "amount": 200, "currency": "HKD", "basis": "redemption", "note": null }
```

`basis` is `redemption` (default, one charge per request) or `transaction`. A single card overrides it in its own card JSON, which is how waivers are expressed without repeating the figure on every card in the program:

```json
"transferFee": { "amount": 0, "currency": "HKD", "note": "Waived for Prestige" }
```

An amount of zero renders as the note, or "No transfer fee". **Display only**, like a gate or a cap: what the fee costs per mile depends on how many points move.

## Rate style (`control/SeedDataPrograms.json`)

A program entry may carry `rateStyle`, which changes only how a rate **reads** — never the maths, which is always `rate × pointCashValue`:

| Style | Reads as | Use when |
|---|---|---|
| `multiplier` (default) | `3x` | Points programs quoted as a multiplier |
| `percent` | `3%` | Cash-back programs whose `rate` is already the percentage (HK cash cards: `7.0` at `pointCashValue: 0.01`) |
| `perMile` | `4% (HK$2.5/里)` | Miles programs **whose `rate` is authored as miles per dollar**. Prints the pair HK cards are quoted in, percentage first |

**`perMile` needs `rate` to mean miles per dollar.** The per-mile half is `1 ÷ rate` and the percentage half is `rate × pointCashValue`, so a program set to `perMile` whose rows are authored percent-style prints a wrong cost. `Asia Miles HK` is the worked example: HK$4 = 1 mile is `rate: 0.25` against `pointCashValue: 0.1015`, which reads `2.54% (HK$4/mile)`. EveryMile and Membership Rewards HK are still authored percent-style, so the style stays unset on them until each card is verified against the issuer's page.

**Authoring a miles card, in order.** Take the issuer's HK$-per-mile figure, write `rate` as `1 ÷ that` (HK$2 → `0.5`, HK$6 → `0.1667`), and set the program's `pointCashValue` to what one mile is actually worth — around HK$0.10 for Asia Miles, not HK$0.01. Getting one of the two wrong and the other wrong in the opposite direction cancels out in the ranking and hides for a long time: `sc-hk-cathay` shipped as `5.0 / 2.5 / 1.67` against `0.01015` for exactly that reason, with every effective rate correct and every displayed rate nonsense.

It is also **gated on the points being able to reach miles**. A program falls back to `multiplier` unless it has an entry in `SeedDataTransferPartners.json`, or it carries `"milesCurrency": true` — the marker for a program whose unit already *is* an airline mile and so needs no transfer (`Asia Miles HK`). That keeps a Chase Freedom on Chase Cash Back Rewards from showing a mile cost until `ProgramUpgradeDatabase` moves it onto Ultimate Rewards. The fallback is `multiplier` rather than `percent` because a `perMile` rate is miles per dollar: printing `0.25` with a `%` would assert a cash rate it is not.

## Pattern 7 — Earning layers (`bankrelationshipprograms/boost_programs.json`)

A bonus that sits **on top of** a card's reward rows: a bank relationship tier, an issuer promotion spanning many cards (HSBC Travel Guru), a category allocation (Red Hot Rewards), a pick-one promo (WeWa), or a card's own always-on extra. The engine resolves every eligible program for a card into the layers that fire for *this* transaction and applies them to whichever reward row wins:

```
((rate + rateAdds) × pointCashValue + cashAdds) × multipliers − FX fee
```

```json
{
  "id": "hsbc-hk-travel-guru", "name": "Travel Guru", "issuer": "HSBC",
  "eligibleIssuer": "HSBC", "eligibleCountry": "HK",        // or "eligibleTemplateIDs": [...]
  "mode": "add", "unit": "cash",                            // mode: multiply (default) | add · unit: rate (default) | cash
  "appliesTo": { "crossBorder": true, "channels": ["in_store"] },
  "excludes":  { "paymentMethods": ["alipay_hk"] },
  "selection": "tier",                                       // tier (default) | allocate | pickOne | always
  "tiers": [ { "name": "GING", "value": 0.04, "description": "…", "cap": { "amount": 30000, "currency": "HKD", "period": "year", "kind": "spend" } } ],
  "footnote": "…"
}
```

| Field | Notes |
|---|---|
| `eligibleTemplateIDs` / `eligibleIssuer` + `eligibleCountry` | Scope. Either form; issuer + country lets new cards join without editing the program. |
| `mode` | `multiply`: the tier's `multiplier` scales the whole earn (US relationship tiers). `add`: the `value` is added on top. |
| `unit` | For `add`. `rate` = points per dollar, same unit as `rate` on a reward row. `cash` = added after the point value (0.03 = 3%), so one layer fits cards whose programs differ. |
| `appliesTo` / `excludes` | `categories` (may name `foreign_transactions` / `online_transactions` like a reward row), `channels`, `crossBorder`, `countries`, `currencies`, `paymentMethods`. `appliesTo`: every stated dimension must hold. `excludes`: any match knocks the layer out. `currencies` and `paymentMethods` use the same derivation as reward rows (since part 3). A `paymentMethods` *exclusion* bites only when every way the purchase could be paid is excluded — the optimistic set still lets the user pay by card. |
| `selection` | `tier`: `tiers[]` with `multiplier` or `value` each. `allocate`: `allocation: {categories, total, maxPerCategory}` and a per-weight `value`; the user spreads weights, and each allocated category becomes its own layer. `pickOne`: `options[]` and a `value`. `always`: on for every eligible card with nothing to enrol in (a card's own extra), `value` required. |
| `gate` / `cap` | `{amount, currency, period, kind, group, note}` — **display only**, the app tracks no spend. Same shape and same formatter (`ConditionText`) as a reward row's. `period`: calendarMonth · statementCycle · quarter · halfYear · year · promo. `kind`: spend · reward. A tier's `cap` overrides the program's. `group` names a shared pool. |

Gotchas: program `id`s, tier `name`s and allocation category ids are all load-bearing (`User.boostEnrollments`). A layer scoped to `crossBorder` or a channel never shows in the card-info earning rows (no transaction there); Reward Setup lists it with its scope instead. The `add` value for HSBC RewardCash is `0.004` per X (1X = 0.4%).

---

## Gotchas

- **Matching vs display are separate.** Only `category`/`categories` (plus merchant/channel/country/date constraints) affect the pricing engine. `groupLabel`, `rewardNotes` are display-only.
- **Trailing commas silently kill the file** (see top).
- ~~**`countries` quirk**~~ — fixed in P1f part 3; both decoders now carry `countries`, `currencies`, `excludedCountries` and `paymentMethods`.
- **New user-facing labels** (`groupLabel`, option labels) are currently English-only — unlike category names, they have no zh variants yet.
- Field changes to `RewardRate` need a schema version bump (`ChurSchema.swift`) and a `DataDictionary.md` update; new JSON fields must be decoded in **both** `SeedDataLoader.swift` and `CardDatabase.swift`, and synced in `CardSyncService.updateRewardFields`.
