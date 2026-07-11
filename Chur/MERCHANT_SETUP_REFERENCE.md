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

## 2. Online Merchant

`File: categories/merchants_mapping/SeedDataOnlineMerchants.json`

```json
{
  "id": "netflix",
  "name": "Netflix",
  "domain": "netflix.com",
  "category": "stream_netflix",
  "merchantIconName": "icon_netflix",
  "isBrandCategory": true,
  "businessRegion": null,
  "tags": ["streaming", "entertainment"],
  "paymentMethods": null,
  "sortOrder": 10,
  "merchantDescription": null,
  "featured": ["US", "HK", "TW"],
  "popular": ["US", "HK", "TW"]
}
```

### Key fields

| Field | Effect on pricing engine |
|---|---|
| `category` | Becomes `category:` param in `CardRateCalculator` |
| `isBrandCategory: true` | Enables `OnlineMerchantDatabase.merchant(forCategory:)` icon lookups; marks category as brand-exclusive |
| `paymentMethods: null` | Online merchants: `null` → `acceptedPaymentMethods = Set()` → **no payment-method rewards apply**. Provide `["apple_pay"]` etc. to enable them |
| `businessRegion` | `null` = global. Array = only shown in those regions |
| `featured` | Appears in the 3×3 featured grid for those regions |

**Channel passed to calculator:** always `"online"`.

---

## 3. On-Map Merchant (MapKit / Nearby)

`File: categories/merchants_mapping/SeedDataMerchantMappings.json`

The file is an **object with four matching strategies** (decoded by `Nearby_Engine_CategoryMapper.swift`), not a flat array. A typical merchant goes in `patternRules`:

```json
{
  "exactMatches": { "netflix": "stream_netflix" },
  "prefixMatches": [ { "prefix": "7-eleven", "categoryID": "convenience", "requiredPOI": null } ],
  "containsMatches": [ { "keyword": "marriott", "categoryID": "marriott_hotels", "requiredPOI": null } ],
  "patternRules": [
    {
      "patterns": ["netflix", "hulu", "disney+", "peacock"],
      "categoryID": "video_streaming",
      "overrides": [ { "ifContains": "gas", "categoryID": "costco_gas" } ]
    }
  ]
}
```

### Key fields

| Field | Notes |
|---|---|
| `exactMatches` | Lowercased full place name → categoryID |
| `prefixMatches` / `containsMatches` | Prefix / anywhere-substring match, optionally gated on a MapKit POI category (`requiredPOI`) |
| `patterns` (in `patternRules`) | Case-insensitive substring match against the MapKit place name; `overrides` swap the categoryID when an extra keyword is present (e.g. Costco gas station) |
| `categoryID` | `SpendingCategory.id` passed to `CardRateCalculator`. Use the closest stable category — brand targets (`stream_netflix`) are fine for tight patterns; generic children (`video_streaming`) are safer when map data varies |

**Channel passed to calculator:** `"in_store"` (default for map results).

> If a merchant exists in both files, the online entry uses `category: "stream_netflix"` (specific), while the map entry may use `"video_streaming"` (broad) — this is intentional, since map place names don't always identify the brand precisely.

---

## 4. Icon Assets

Add the merchant icon to `xcassets` with the name matching `merchantIconName`.
The icon lookup chain in the UI is:
1. `merchant.merchantIconName` (exact asset name)
2. `OnlineMerchantDatabase.merchant(forCategory:)?.merchantIconName` (fallback via category)
3. Category emoji/icon

---

## 5. Full Checklist

### Category
- [ ] Exists in a `SeedDataCategories_*.json` file
- [ ] `level` set correctly: `"parent"` / `"child"` / `"target"`
- [ ] `parentCategoryID` set to direct parent
- [ ] No `categoryLinks` (only add for a cross-link or isolated brand — see section 1)
- [ ] `excludeFromParent` is absent or `false` (unless isolated brand)
- [ ] No `channels` restriction on parent/grandparent categories
- [ ] Run the app in DEBUG — `SeedDataValidator` prints ⚠️ for broken refs and pricing invariants

### Online merchant
- [ ] Entry in `SeedDataOnlineMerchants.json`
- [ ] `category` matches a valid `SpendingCategory.id`
- [ ] `isBrandCategory` set correctly (`true` = brand-exclusive category)
- [ ] `paymentMethods` declared if Apple Pay / PayPal rewards should apply
- [ ] Icon asset added to xcassets

### On-map merchant
- [ ] Pattern(s) in `SeedDataMerchantMappings.json`
- [ ] Patterns are specific enough to avoid over-matching unrelated places
- [ ] `categoryID` is the right specificity level for map data variability

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
