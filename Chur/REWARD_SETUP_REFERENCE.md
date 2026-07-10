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
| `rate` | ✅ | Multiplier: `3.0` = 3x/3%. Display hides rows with rate ≤ 1.0 unless category is `everything`. |
| `rewardProgramName` | ✅ | Must match a program in the programs seed so `pointCashValue`/currency resolve. |
| `pointCashValue` | — | Per-reward override; otherwise resolved from the program (default `0.01`). |
| `category` | — | Single category ID (legacy form). This is what the pricing engine matches. |
| `categories` | — | Array form — one reward matching several category IDs at the same rate. Preferred over `category` for multi-category. |
| `groupLabel` | — | Display-only group name (see Pattern 3). Never affects matching. |
| `merchantIdentifier` / `merchantName` | — | Merchant-specific rate (e.g. `"amazon"`). |
| `channels` | — | `["online"]`, `["in_store"]`, `["in_app"]` — restricts how the purchase is made. |
| `countries` | — | ISO codes where the rate applies (e.g. `["US"]`). |
| `rewardStartDate` / `rewardEndDate` | — | ISO 8601 (`"2026-07-01T00:00:00Z"`). Expired rewards are hidden. |
| `isRotating` | — | Marks quarterly rotating categories; shows Rotating/Ends badges. Pair with start/end dates. |
| `rewardNotes` | — | Small print shown under the row (caps, conditions). |
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

---

## Gotchas

- **Matching vs display are separate.** Only `category`/`categories` (plus merchant/channel/country/date constraints) affect the pricing engine. `groupLabel`, `rewardNotes` are display-only.
- **Trailing commas silently kill the file** (see top).
- **`countries` quirk:** decoded by `CardDatabase` (templates → user cards) but not by `SeedDataLoader.RewardJSON` — rewards created through SeedDataLoader drop it. Prefer relying on the template path; fix the decoder if this ever matters.
- **New user-facing labels** (`groupLabel`, option labels) are currently English-only — unlike category names, they have no zh variants yet.
- Field changes to `RewardRate` need a schema version bump (`ChurSchema.swift`) and a `DataDictionary.md` update; new JSON fields must be decoded in **both** `SeedDataLoader.swift` and `CardDatabase.swift`, and synced in `CardSyncService.updateRewardFields`.
