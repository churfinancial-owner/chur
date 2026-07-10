# Merchant Setup Reference

How to add a merchant so the pricing engine correctly matches card rewards.
Files live under `Resources/json/`.

---

## 1. Category Hierarchy (SpendingCategory)

`File: categories/SeedDataCategories_<group>.json`

Every merchant must resolve to a `SpendingCategory`. Categories form a tree:

```
parent  (level: "parent", no parentCategoryID)
  └─ child  (level: "child", parentCategoryID: "parent",
              categoryLinks: [{id:"parent"}])
       └─ target  (level: "target", parentCategoryID: "child",
                    categoryLinks: [{id:"child"}])
```

**Real example (streaming):**
```
streaming           ← parent
  └─ video_streaming  ← child,  categoryLinks: [{id:"streaming"}]
       └─ stream_netflix  ← target, categoryLinks: [{id:"video_streaming"}]
```

### Rules

| Rule | Why |
|---|---|
| Set `parentCategoryID` on every non-root category | Powers the step-5 ancestor walk in `matchWeight` |
| `categoryLinks` must include the **direct parent** | Step 2 check — works even when `excludeFromParent: true` |
| For deep hierarchies (3+ levels), also link **grandparent** in `categoryLinks` | A 2-hop parent walk is fragile: if an intermediate category is missing from `allCategories`, the walk breaks and rewards fall to `everything` |
| Leave `excludeFromParent` absent/false unless this is an isolated brand | `true` = blocks all ancestor reward matching; only exact match + explicit `categoryLinks` + `everything` apply |
| Don't add `channels` to parent categories (`streaming`, `video_streaming`) | Would block those reward categories for the channel passed to the calculator |

**`categoryLinks` for a 3-level target — direct parent only is sufficient:**
```json
"categoryLinks": [
  { "id": "video_streaming", "weight": 1.0 }
]
```
The pricing engine pre-computes a full ancestor set at init time (including each ancestor's own `categoryLinks`), so `streaming` is reachable from `stream_netflix` via `video_streaming.categoryLinks` automatically. You only need to list the grandparent in `categoryLinks` if you want it to work even with `excludeFromParent: true`.

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

```json
{
  "patterns": ["netflix", "hulu", "disney+", "peacock"],
  "categoryID": "video_streaming"
}
```

### Key fields

| Field | Notes |
|---|---|
| `patterns` | Case-insensitive substring match against the MapKit place name |
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
- [ ] `categoryLinks` includes direct parent
- [ ] For targets 3+ levels deep: `categoryLinks` also includes grandparent
- [ ] `excludeFromParent` is absent or `false` (unless isolated brand)
- [ ] No `channels` restriction on parent/grandparent categories

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

## 6. Common Failure: Falls to `everything`

**Symptom:** Card rewards for `streaming` or `video_streaming` don't apply; only `everything` base rate shows.

**Causes:**

| Cause | Diagnosis | Fix |
|---|---|---|
| `categoryLinks` missing the relevant ancestor | Step 2 skips; only needed now if `excludeFromParent: true` | Add grandparent to `categoryLinks` only when `excludeFromParent: true` |
| Intermediate category missing from `allCategories` | Step 5 pre-computed set is built from `allCategories` at init; if missing, the ancestor path is broken | Ensure all ancestor categories are in a seed file — `CategorySyncService` logs `⚠️` for broken `parentCategoryID` refs in DEBUG |
| `excludeFromParent: true` accidentally set | Step 4 blocks ancestor walk; only `categoryLinks` + `everything` match | Remove `excludeFromParent` or add ancestors to `categoryLinks` |
| Card reward has `channels: ["in_store"]` | Blocked by direct `reward.channels` check for online merchant | Intentional — streaming rewards on some cards may be in-store only |
| `categoryLinksJSON` corrupted in SwiftData | `categoryLinks` computed property returns nil; step 2 skips | Run CategorySyncService to re-sync from bundle templates |
