# Map Search Reference

How Chur's nearby-merchant map search works — the home screen "nearby"
section and the full "all merchants" map search (`Features/Search/`) are
**the same pipeline**: both call `NearbyPlacesService.searchNearby`. Read
this before touching `Core/Map/Mapkit_*`, `Nearby_Engine*`, or
`Features/Search/*`. **Update this file whenever a bucket, cap, or POI
category mapping changes.**

Built July 2026.

---

## 1. The one idea that matters: bucketed parallel search

MapKit's `MKLocalSearch` only accepts one `MKPointOfInterestFilter` per
request and returns a limited, relevance-ranked (not distance-ranked) set
of results. To get a diverse "restaurants AND gas stations AND
pharmacies..." result set within one search, `NearbyPlacesService`
(`Core/Map/Mapkit_NearbyPlacesService.swift`) fires several `MKLocalSearch`
requests in parallel — one per **bucket** — and merges them.

Two searches happen depending on context:

- **Scenario A — a specific filter chip is active** (e.g. "Gas" in
  `NearbyFilter`): one `performSearch` call with that chip's POI
  categories, capped at `maxMerchantsToProcess`.
- **Scenario B — "All"**: one `performSearch` call per bucket group below,
  each independently capped, then merged/deduplicated/sorted by distance
  and truncated to `maxMerchantsToProcess`.

**Bucket groups** (`Mapkit_NearbyPlacesService.swift`):

| Bucket | POI categories | Cap |
|---|---|---|
| `diningBuckets` | restaurant, cafe, bakery | 10 |
| `nightlifeBuckets` | brewery, winery, distillery, nightlife | 10 |
| `transportBuckets` | gasStation, evCharger, publicTransport, parking, carRental | 10 |
| `retailBuckets` | store, pharmacy, foodMarket | 10 |
| `travelBuckets` | hotel, hospital, postOffice, university | 10 |
| `entertainmentBuckets` | theater, movieTheater, amusementPark, museum, fitnessCenter, golf, spa, beauty, stadium, musicVenue | 10 |

`maxMerchantsToProcess = 40` is the final cap after merge — the ceiling on
how many merchants ever reach the recommendation engine.

**Gotcha (fixed July 2026):** a merchant can be silently dropped without
any "tier" or filtering logic ever running against it — it just loses out
on its bucket's cap. Grocery stores (`.foodMarket`) used to share a bucket
with restaurants/cafes/bars, so a Safeway would compete with every nearby
coffee shop for the same 10 slots. If you're diagnosing a "well-known
merchant missing from results" report, check bucket assignment and the
caps above before assuming a matching bug — `MerchantCategoryMapper`
(§3) never excludes a merchant, it always resolves to at least
`"everything"`.

**Gotcha (fixed July 2026):** `MKLocalSearch` results are not
distance-ordered. `performSearch` must sort by distance **before**
`.prefix(limit)` truncates to the bucket cap, or the true closest results
can be cut in favor of farther, MapKit-relevance-ranked ones.

---

## 2. Adding or rebalancing a bucket

- Group POI categories that are unlikely to crowd each other out in a
  dense area. Don't mix a narrow, high-value category (groceries, gas)
  with a broad, high-volume one (restaurants, bars) — the narrow one will
  starve.
- Each bucket adds one parallel `MKLocalSearch` request — there's no hard
  limit on bucket count, but more buckets means more concurrent requests
  per search.
- If a bucket's cap of 10 is consistently insufficient (e.g. dense urban
  retail), raise that bucket's `limit` in `performSearch`, and raise
  `maxMerchantsToProcess` to match so the merge step doesn't re-introduce
  the same starvation.
- `NearbyFilter.poiCategories` (`Features/Search/View/NearbyFilter.swift`)
  is a separate, smaller POI list per filter chip (Scenario A) — keep it
  in sync if you rename/move a category between buckets.

---

## 3. Merchant/category matching — never a filter

`MerchantCategoryMapper.mapToCategory` (`Core/Map/Nearby_Engine_CategoryMapper.swift`)
assigns a category ID to every `MKMapItem` that survives the bucket caps.
Strategy order: exact name match → prefix+POI → contains+POI → merchant
map patterns → generic pattern rules → raw POI category → `"everything"`
fallback. This function **always returns a category ID** — it never
removes a merchant from the results list. See
`MERCHANT_SETUP_REFERENCE.md` for how merchant JSON entries feed this.

Note: "target" in this codebase refers to `CategoryLevel` (parent → child
→ target, the leaf level of the category hierarchy used for `matchWeight`
resolution) — there is no merchant "tier" or visibility allowlist. If a
merchant seems to be excluded from map results, the cause is almost always
the bucket/cap mechanism in §1, not category matching.

---

## 4. Where results get displayed vs. filtered

- `Search_Map_ViewModel.swift` / `Search_Map_View.swift` (full map search)
  and the home nearby section both consume `searchNearby`'s output
  directly — no additional exclusion happens between the service and the
  view beyond `NearbyFilter.matches(_:categories:)`, which is a **display**
  filter (hides merchants outside the selected chip's `rootCategoryIDs`)
  applied after the MapKit search already ran, not a data-fetching filter.
- The pricing/reward engine (`Nearby_Engine.swift`,
  `CardRateCalculator.swift`) can fail to find a matching card reward
  (`hasMatch: false`, "❓" fallback) — this affects what reward is shown,
  never whether the merchant itself appears in the list.

---

## 5. Query volume and card-matching cost

Both screens share the same risk surface: a full "All" search fans out to
6 parallel `MKLocalSearch` requests (§1), and Apple doesn't publish a
numeric rate limit for `MKLocalSearch` — but it's known to return
`MKError.loadingThrottled` if hit too fast/too often. Keep this in mind
before adding more buckets or more search triggers.

**Home screen throttling** (`Features/Home/View/Nearby/View_NearbyRecommendations.swift`):
- `LocationManager` (`Core/Map/Access_LocationManager.swift`) sets
  `distanceFilter = 100`, so CoreLocation itself won't deliver a new
  `location` more often than every ~100m of movement — walking/shopping
  is already naturally throttled at the OS level.
- On top of that, the `.onChange(of: locationManager.location)` handler
  adds a **3-second debounce** (`Task.sleep` before searching) to cover
  sustained driving, where 100m ticks can arrive every few seconds and
  would otherwise re-fire the 6-bucket search on every tick.
- The full map search screen (`Search_Map_ViewModel.swift`) has its own,
  separate 0.8s debounce on camera/filter changes (`cancelAndSearch()`) —
  keep both in sync in spirit if you touch either.
- Neither screen caches results by location (`lastSearchedCenter` in
  `Search_Map_ViewModel.swift` is currently unused for this) — panning
  back over an already-searched area re-queries MapKit. Not a problem
  today given the debounces above, but worth knowing if throttling
  reports come in.

**Card-matching cost** (`Nearby_Engine.swift`, `CardRateCalculator.swift`):
- `CardRateCalculator.CategoryMaps` precomputes the category→ancestor-set
  map once; `NearbyRecommendationEngine.recommendAll`/`recommendAllOnline`
  build it **once per batch** and pass it to every `recommend(for:)` call,
  instead of each merchant's `CardRateCalculator` rebuilding the same map
  from scratch. If you add a new call site that matches many merchants at
  once, build a `CategoryMaps` up front and pass it through rather than
  relying on the default (which still rebuilds per-instance — needed for
  existing single-merchant callers like the debug calculator popup).
- The home screen caches its `recommendations` in `@State` and only
  recomputes on `.onChange(of: nearbyMerchants)`, a `cardsFingerprint`
  (hash of card/plan/reward IDs — `CreditCard` is a SwiftData `@Model`
  class, so comparing the array by reference won't catch in-place reward
  changes; see `EarningPowerTabView.cardsFingerprint` for the same
  pattern), or `boostEnrollments`. Don't turn `recommendations` back into
  a plain computed `var` — that reruns the full matching pass on every
  SwiftUI re-render, not just when the inputs change.
- The full map search screen already avoids this class of cost entirely:
  it defers card matching to the per-merchant detail popup opened on tap
  (`Search_Map_View.swift`), rather than matching the whole visible list.
