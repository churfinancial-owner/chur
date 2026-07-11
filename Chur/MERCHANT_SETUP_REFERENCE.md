# Merchant Setup Reference

How to add a merchant so the pricing engine correctly matches card rewards.
Files live under `Resources/json/`.

---

## 1. Category Hierarchy (SpendingCategory)

`File: categories/SeedDataCategories_<group>.json`

Every merchant must resolve to a `SpendingCategory`. Categories form a tree
driven **entirely by `parentCategoryID`**:

```
parent  (level: "parent", no parentCategoryID)
  └─ child  (level: "child", parentCategoryID: "parent")
       └─ target  (level: "target", parentCategoryID: "child")
```

**Real example (streaming — see `SeedDataCategories_streaming.json`, the template exemplar):**
```
streaming           ← parent
  └─ video_streaming  ← child,  parentCategoryID: "streaming"
       └─ stream_netflix  ← target, parentCategoryID: "video_streaming"
```

### Rules

| Rule | Why |
|---|---|
| Set `parentCategoryID` on every non-root category | Powers the step-5 ancestor walk in `matchWeight` — this alone makes all ancestor rewards apply |
| **Omit `categoryLinks`** for normal categories | The parent chain already covers them; links are only for the two cases below |
| Leave `excludeFromParent` absent/false unless this is an isolated brand | `true` = blocks all ancestor reward matching; only exact match + explicit `categoryLinks` + `everything` apply |
| Don't add `channels` to parent categories (`streaming`, `video_streaming`) | Would block those reward categories for the channel passed to the calculator |

### When `categoryLinks` IS needed (the only two cases)

Format is a plain array of category IDs (the legacy `{"id": ..., "weight": ...}` object form still decodes but should not be used in new entries):

```json
"categoryLinks": ["amazon"]
```

1. **Cross-link into another branch** — a second "parent" the tree can't express.
   `wholefood` has `parentCategoryID: "groceries"` *and* `"categoryLinks": ["amazon"]`
   so Amazon-card rewards also apply at Whole Foods.
2. **Isolated brand** — `parentCategoryID: null` (or `excludeFromParent: true`) so no
   ancestor cascade applies, with a link as the *only* reward connection.
   `costco` has no parent and `"categoryLinks": ["wholesale"]`: wholesale cards match,
   generic grocery cards do not.

### How `matchWeight` resolves (priority order)

1. Exact match: `rewardCategory == category.id` → 1.0
2. Explicit `categoryLinks` on the merchant category → 1.0  *(works even with `excludeFromParent`)*
3. Payment method fallback (`apple_pay`, `mobile_pay`, `paypal_pay`) → 1.0
4. Gate: if `excludeFromParent == true` → stop (only `everything` passes below)
5. Pre-computed ancestor set lookup (`ancestorsByCategoryID[category.id]?.contains(rewardCategory)`) → 1.0  
   *Set includes all ancestors' IDs plus their `categoryLinks` IDs — computed once in `CardRateCalculator.init`, O(1) per match*
6. Universal fallback: `rewardCategory == "everything"` → 1.0
7. No match → 0.0

---

## 2. Merchant — the unified seed

`File: json/merchants_mapping/SeedDataMerchants.json` — **one entry per merchant** covers online search, map matching, and (optionally) an auto-generated brand category.

> ⚠️ `SeedDataOnlineMerchants.json` and `SeedDataMerchantMappings.json` are **dead** — no code reads them. They remain on disk only as the data source for the ongoing migration into `SeedDataMerchants.json`.

```json
{
  "merchants": [
    {
      "id": "netflix",
      "name": "Netflix",
      "domain": "netflix.com",
      "category": "stream_netflix",
      "merchantIconName": "icon_netflix",
      "isBrandCategory": true,
      "tags": ["streaming", "entertainment"],
      "sortOrder": 10,
      "featured": ["US", "HK", "TW"],
      "popular": ["US", "HK", "TW"],
      "brandCategory": { "parent": "video_streaming", "emoji": "▶️" },
      "map": { "patterns": ["netflix"] }
    }
  ],
  "genericMappings": { "...": "see section 3" }
}
```

### Key fields

| Field | Effect |
|---|---|
| `category` | Becomes `category:` param in `CardRateCalculator` |
| `brandCategory` | **Auto-generates the target `SpendingCategory`** (`id` = `category`, name/icon from the merchant, `parent`/`links`/`emoji` from the block). No hand-authored category file entry needed. Omit it when the category is hand-authored (needed for `cardFilter`, localized names, `excludedPaymentMethods` — e.g. costco). Hand-authored wins on ID conflict, with a DEBUG warning. |
| `map` | Map name-matching: `patterns` are case-insensitive substrings of the MapKit place name; optional `categoryID` (defaults to `category`) and `overrides`. Merchant rules are checked **before** `genericMappings.patternRules`. |
| `searchable: false` | Map-only merchant — hidden from the Online search mode |
| `isBrandCategory: true` | Enables `OnlineMerchantDatabase.merchant(forCategory:)` icon lookups; marks category as brand-exclusive |
| `paymentMethods` | Omitted/`null` → **no payment-method rewards apply** online. Provide `["apple_pay"]` etc. to enable them |
| `businessRegion` | Omitted/`null` = global. Array = only shown in those regions |
| `featured` / `popular` | Featured grid / default list for those country codes |

**Channel passed to calculator:** `"online"` for online search, `"in_store"` for map results.

---

## 3. Generic Map Mappings (non-merchant rules)

`genericMappings` inside `SeedDataMerchants.json` holds map rules that don't belong to a single merchant entry: POI-gated brand prefixes, multi-brand patterns, and name quirks. Decoded into `MerchantMappings` (`MerchantSeedDatabase.swift`), consumed by `Nearby_Engine_CategoryMapper.swift`.

```json
"genericMappings": {
  "exactMatches": { "amazon fresh": "wholefood" },
  "prefixMatches": [
    { "prefix": "costco", "categoryID": "costco", "requiredPOI": "MKPOICategoryStore" },
    { "prefix": "costco", "categoryID": "costco_gas", "requiredPOI": "MKPOICategoryGasStation" }
  ],
  "containsMatches": [ { "keyword": "marriott", "categoryID": "marriott_hotels", "requiredPOI": null } ],
  "patternRules": [ { "patterns": ["hulu", "disney+"], "categoryID": "video_streaming" } ]
}
```

Matching priority at runtime: `exactMatches` → `prefixMatches` (+POI) → `containsMatches` (+POI) → merchant `map` rules → generic `patternRules` → POI category → `everything`.

| Field | Notes |
|---|---|
| `exactMatches` | Lowercased full place name → categoryID |
| `prefixMatches` / `containsMatches` | Prefix / anywhere-substring match, optionally gated on a MapKit POI category (`requiredPOI`) |
| `patternRules` | Substring match with optional `overrides` (e.g. `ifContains: "gas"` → `costco_gas`) |
| `categoryID` | Use the closest stable category — brand targets for tight patterns, generic children when map data varies |

---

## 4. Icon Assets

Add the merchant icon to `xcassets` with the name matching `merchantIconName`.
The icon lookup chain in the UI is:
1. `merchant.merchantIconName` (exact asset name)
2. `OnlineMerchantDatabase.merchant(forCategory:)?.merchantIconName` (fallback via category)
3. Category emoji/icon

---

## 5. Full Checklist

### Category — skip entirely if the merchant uses `brandCategory` auto-generation
- [ ] Exists in a `SeedDataCategories_*.json` file
- [ ] `level` set correctly: `"parent"` / `"child"` / `"target"`
- [ ] `parentCategoryID` set to direct parent
- [ ] No `categoryLinks` (only add for a cross-link or isolated brand — see section 1)
- [ ] `excludeFromParent` is absent or `false` (unless isolated brand)
- [ ] No `channels` restriction on parent/grandparent categories
- [ ] Run the app in DEBUG — `SeedDataValidator` prints ⚠️ for broken refs and pricing invariants

### Merchant (one entry in `SeedDataMerchants.json`)
- [ ] `category` is either auto-generated via `brandCategory` **or** matches a hand-authored `SpendingCategory.id`
- [ ] `map.patterns` added if the merchant has physical locations; specific enough to avoid over-matching unrelated places
- [ ] `searchable: false` if the merchant should not appear in Online search
- [ ] `isBrandCategory` set correctly (`true` = brand-exclusive category)
- [ ] `paymentMethods` declared if Apple Pay / PayPal rewards should apply online
- [ ] Icon asset added to xcassets (name = `merchantIconName`)

---

## 6. Cleaning Up a Legacy Category File

Older `SeedDataCategories_*.json` files still carry redundant `categoryLinks`
(and the obsolete `weight` field). To migrate one file — `SeedDataCategories_streaming.json`
is the finished exemplar:

1. Delete any `categoryLinks` whose only entry is the category's own `parentCategoryID`,
   and any `"categoryLinks": null`.
2. Keep links that point anywhere else (cross-links, isolated brands) and rewrite them
   as plain strings: `"categoryLinks": ["amazon"]` — drop `weight`.
3. If a kept link disagrees with `parentCategoryID` (e.g. old `stream_spotify`:
   parent `streaming`, link `music_streaming`), decide which is the real parent —
   usually the more specific one — and fix `parentCategoryID` instead of keeping the link.
4. Build & run in DEBUG: `SeedDataValidator` must print ✅ (it checks refs and
   pricing invariants for costco / wholefood / stream_netflix).

---

## 7. Common Failure: Falls to `everything`

**Symptom:** Card rewards for `streaming` or `video_streaming` don't apply; only `everything` base rate shows.

**Causes:**

| Cause | Diagnosis | Fix |
|---|---|---|
| `parentCategoryID` missing or wrong | Step 5 ancestor walk never reaches the reward category | Set `parentCategoryID` to the direct parent; `SeedDataValidator` flags unresolvable parents at launch in DEBUG |
| Intermediate category missing from `allCategories` | Step 5 pre-computed set is built from `allCategories` at init; if missing, the ancestor path is broken | Ensure all ancestor categories are in a seed file — `SeedDataValidator` and `CategorySyncService` log `⚠️` in DEBUG |
| `excludeFromParent: true` accidentally set | Step 4 blocks ancestor walk; only `categoryLinks` + `everything` match | Remove `excludeFromParent` or add ancestors to `categoryLinks` |
| Card reward has `channels: ["in_store"]` | Blocked by direct `reward.channels` check for online merchant | Intentional — streaming rewards on some cards may be in-store only |
| `categoryLinksJSON` corrupted in SwiftData | `categoryLinks` computed property returns nil; step 2 skips | Run CategorySyncService to re-sync from bundle templates |
