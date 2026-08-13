# Chur — Data Dictionary

**Schema version:** 2.0.0 — frozen baseline. Collapses the non-functional v1.10 … v1.14 ladder, which listed the same live `@Model` classes in every version and so could never migrate anything (audit note 1b)  
**Migration plan:** `ChurMigrationPlan` in `Core/Sync/ChurSchema.swift` — **read its header before changing any `@Model`**. Pre-launch, model changes do *not* each need a new version (there is no shipped store to migrate from); after v1.0 ships, every one does. The header spells out both modes  
**Schema guard:** `Core/Sync/SchemaFingerprint.swift` fails a DEBUG assertion if a model changes without a version bump  
**Store recovery:** `Core/Sync/ChurStoreRecovery.swift` quarantines an unreadable store and starts fresh instead of crashing on launch  
**Backup version:** `ChurBackup.currentVersion = 3` — increment and add migration case in `CloudSyncManager.migrate(_:)` for any breaking DTO change  
**Persistence:** SwiftData (SQLite on-device)  
**Cloud sync:** Google Drive App Data (JSON snapshot, Google-authenticated users only); Apple Sign In users and anonymous users currently have no cloud backup — CloudKit planned. For those users the local store is the only copy, which is why the migration plan has to be correct rather than leaning on store recovery  
**Seed data authoring:** see `Resources/json/REWARD_SETUP_REFERENCE.md` (rewards) and `Resources/json/MERCHANT_SETUP_REFERENCE.md` (categories/merchants)  
**Last updated:** 2026-08-13

> SwiftData auto-generates an opaque `PersistentIdentifier` for every `@Model` instance.  
> This acts as the internal primary key and is not exposed as a Swift property.  
> Where a model defines its own `id: String`, that field is the **application-level primary key** — used for cross-reference and sync, but distinct from SwiftData's internal PK.

---

## ⚠️ Load-bearing IDs — never rename, never remove

Some seed-data ids are pointed at by **persisted user data**. Renaming or deleting one is destructive, and nothing catches it: the ids live in JSON, so the compiler is never involved, and since P1a/P1b that JSON publishes remotely — reaching devices within 30 minutes, with no build in between.

| Seed id | Pointed at by | What a rename costs the user |
|---|---|---|
| Card `id` (`json/cards/**`) | `CreditCard.templateID` | Card silently stops syncing and keeps stale rates forever |
| Benefit `id` (`json/benefits/**`) | `Benefit.id` suffix | **Redemption history destroyed** — `Benefit.usageHistory` is `.cascade`, and `CardSyncService.syncBenefits` deletes benefits the template no longer lists |
| `planID` (`json/rewards/*`) | `CreditCard.selectedPlanID` | Chosen reward plan resets to nil |
| `configurableSlot` (`json/rewards/*`) | `CreditCard.slotSelections` keys | Slot picks orphaned; `reward.categories` re-derive wrong |
| Category `id` (`json/categories/*`, plus `brandCategory`-derived) | `User.selectedCategories`, `deselectedCategories`, `explicitlySelectedParentCategories` | Picks go inert — the row is deactivated, the preference points at nothing |

**Enforced, not remembered:** `Scripts/ChurContentPublish/id-lock.json` records every id ever published, and `swift run ChurContentPublish` refuses to publish when an active one disappears. A rename trips it automatically, because a rename is an addition plus a removal. There is no override flag.

**To retire an id properly:** keep the entry in the seed data so the id still resolves, hide it (categories: `"visibility": "hidden"`, including `brandCategory.visibility` for merchant-derived ones; benefits: `"isActive": false`), and move the id from `active` to `retired` in the lock file. Deleting the entry outright is what strands user references.

Everything else in the seed JSON — names, rates, descriptions, values, ordering — is free to change.

---

## At a glance — model registry

Every `@Model` in the app, whether the schema persists it, and how much of it survives a cloud restore. **A model missing from `ChurSchemaV2_0.models` is silently not persisted** — no build error, no runtime warning, it just never reaches disk.

| Model | File | In `ChurSchemaV2_0` | Cloud backup | § |
|---|---|---|---|---|
| `User` | `Features/User/Data/User.swift` | ✅ | Partial — preferences and identity; auth fields re-derived at sign-in | [1](#1-user) |
| `CreditCard` | `Features/Cards/DataModel/CreditCard.swift` | ✅ | Partial — identity + user edits; rewards/benefits re-seeded | [2](#2-creditcard) |
| `RewardPlan` | `Features/Rewards/DataModel/RewardPlan.swift` | ✅ | ❌ — re-seeded from template; only `CreditCard.selectedPlanID` carries over (audit note 16) | [3](#3-rewardplan) |
| `RewardRate` | `Features/Rewards/DataModel/RewardRate.swift` | ✅ | Partial — only `hasCustomPointValue` + `pointCashValue`; the rest re-seeded | [4](#4-rewardrate) |
| `Benefit` | `Features/Benefit/DataModel/Models/Benefit.swift` | ✅ | Partial — user state only (activation, auto-apply, mute); template content re-seeded | [5](#5-benefit) |
| `BenefitUsageRecord` | `Features/Benefit/DataModel/Models/BenefitUsageRecord.swift` | ✅ | ✅ Full | [6](#6-benefitusagerecord) |
| `CardProductChangeEvent` | `Features/Cards/DataModel/CardProductChangeEvent.swift` | ✅ | ✅ Full (since backup v3) | [7](#7-cardproductchangeevent) |
| `SpendingCategory` | `Features/Rewards/View/SpendingCategory.swift` | ✅ | ❌ — seed data, rebuilt from JSON. The user's *choices* live on `User.selectedCategories` etc. | [8](#8-spendingcategory) |
| `MerchantReward` | `Features/Rewards/DataModel/MerchantReward.swift` | ❌ **not registered** | ❌ | [9](#9-merchantreward--orphaned) |

**The restore model, in one line:** the backup carries only what the user authored — template content is re-seeded from JSON by `CardSyncService`, then user deltas are applied on top (`BackupRestoreService`). This is why "Partial" is correct rather than a gap: a restored card gets current reward rates rather than stale ones from whenever the backup was taken.

**The failure mode it creates:** any *new* user-editable field is invisible to the backup until someone adds it to the DTO, and nothing fails when they don't — the field just silently resets on every restore. That is exactly how the nine fields in audit notes 14–15 were lost, including one that produced wrong money (`Benefit.autoApplyAmount`). **When you add a user-editable field to a model, add it to `CloudSyncManager` and `BackupRestoreService` in the same commit.**

---

## Table of Contents

1. [User](#1-user)
2. [CreditCard](#2-creditcard)
3. [RewardPlan](#3-rewardplan)
4. [RewardRate](#4-rewardrate)
5. [Benefit](#5-benefit)
6. [BenefitUsageRecord](#6-benefitusagerecord)
7. [CardProductChangeEvent](#7-cardproductchangeevent)
8. [SpendingCategory](#8-spendingcategory)
9. [MerchantReward ⚠️ Orphaned](#9-merchantreward--orphaned)
10. [In-Memory / Static Structures (not persisted)](#10-in-memory--static-structures-not-persisted)
11. [Relationships Overview](#11-relationships-overview)
12. [Audit Notes & Risks](#12-audit-notes--risks)

---

## 1. User

**File:** `Features/User/Data/User.swift`  
**Role:** Singleton — one record per device. Represents the authenticated (or anonymous) local user.

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `firstName` | `String` | Not Null, default `""` | — | User's given name. Populated from Apple/Google sign-in; may be empty for anonymous users. |
| `email` | `String` | Not Null, default `""` | — | User's email address. Populated from Apple/Google. Empty for anonymous users. |
| `appleUserID` | `String` | Not Null, default `""` | — | Stable opaque user ID from Sign in with Apple. Empty if not signed in with Apple. |
| `googleUserID` | `String` | Not Null, default `""` | — | Google user ID from GIDSignIn. Empty if not signed in with Google. |
| `onboardingCompleted` | `Bool` | Not Null | — | Gate flag observed by `RootView`. `false` = route to onboarding flow. |
| `locationEnabled` | `Bool` | Not Null | — | User's location preference. Does **not** directly control OS permission. |
| `dateAdded` | `Date` | Not Null | — | Timestamp of account creation (first app launch). |
| `selectedCategories` | `[String]` | Not Null, default `[]` | References `SpendingCategory.id` | Category IDs the user has opted into for Earning Power calculations. |
| `deselectedCategories` | `[String]` | Not Null, default `[]` | References `SpendingCategory.id` | Category IDs explicitly unchecked by the user in the picker. |
| `explicitlySelectedParentCategories` | `[String]` | Not Null, default `[]` | References `SpendingCategory.id` | Parent category IDs the user intentionally toggled on. Separates explicit from inherited selection. |
| `cardDisplayOrder` | `[String]` | Not Null, default `[]` | References `CreditCard.id` | Ordered list of card instance IDs reflecting the user's custom card sort. |
| `showEffectiveRate` | `Bool` | Not Null, default `false` | — | If `true`, displays effective cash-back rate (rate × pointCashValue) instead of raw multiplier. |
| `boostEnrollments` | `[String: String]` | Not Null, default `[:]` | Key references `BoostProgram.id` (static) | Maps boost program ID → enrolled tier name (e.g. `"bofa-preferred-rewards"` → `"Platinum Honors"`). |
| `country` | `String` | Not Null, default locale-detected | — | User's preferred country for card database filtering (e.g. `"US"`, `"HK"`). |
| `languagePreference` | `String` | Not Null, default `"system"` | — | User's explicit app language override. `AppLanguage.rawValue`: `"system"`, `"english"`, or `"zh-Hant-HK"`. `"system"` means follow device `Locale.current`. Resolved via `AppLocale` (`Core/Localization/AppLocale.swift`), mirrored to `UserDefaults["appLanguage"]` for synchronous access before a `User`/`ModelContext` is available. |
| `earningPowerTravelModeEnabled` | `Bool` | Not Null, default `false` | — | Forces cross-border FX fee logic in Earning Power calculations regardless of current location. |
| `profilePhotoData` | `Data?` | Nullable | — | Compressed JPEG binary of the user's profile photo. Nil = no photo set. |
| `profileEmoji` | `String` | Not Null, default `"😊"` | — | Emoji avatar shown when no photo is set. |
| `authProvider` | `String` | Not Null, default `"anonymous"` | — | Authentication state. Allowed values: `"apple"`, `"google"`, `"anonymous"`. |
| `strategyPreferences` | `[String]` | Not Null, default `[]` | — | Financial Aura selections (e.g. `["jetsetter", "socialite"]`). Drives recommendation sorting. |

---

## 2. CreditCard

**File:** `Features/Cards/DataModel/CreditCard.swift`  
**Role:** One record per card in the user's wallet. Contains all card metadata, customizations, and cascades to rewards and benefits.

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `id` | `String` | Not Null, application PK (UUID) | — | Card instance ID generated at add-time (`UUID().uuidString`). Stable for the lifetime of this wallet entry. |
| `templateID` | `String?` | Nullable | References `CardDatabase` (static JSON, not persisted) | Links this instance to its catalog template. `nil` for fully custom (non-catalog) cards. |
| `name` | `String` | Not Null | — | Display name of the card (e.g. `"Chase Sapphire Reserve"`). |
| `issuer` | `String` | Not Null | — | Issuing bank name (e.g. `"Chase"`, `"American Express"`). |
| `network` | `String` | Not Null | — | Payment network (e.g. `"Visa"`, `"Mastercard"`, `"American Express"`, `"Discover"`). |
| `imageName` | `String` | Not Null | — | Asset catalog key or bundle resource name for the card art. |
| `hasCustomImage` | `Bool` | Not Null, default `false` | — | `true` if the user uploaded a custom card image. |
| `cardType` | `String` | Not Null, default `"personal"` | — | `"personal"` or `"business"`. Affects reward and benefit eligibility. |
| `isAuthorizedUser` | `Bool` | Not Null, default `false` | — | `true` if the user is an authorized user (not primary cardholder). |
| `annualFee` | `Int` | Not Null, default `0` | — | Annual fee in the card's billing currency (integer cents/dollars). |
| `approvedMonth` | `Int` | Not Null, range 1–12 | — | Month the card was approved. Used for card anniversary calculations. |
| `approvedDay` | `Int` | Not Null, range 1–31 | — | Day of month the card was approved. |
| `approvedYear` | `Int` | Not Null | — | Year the card was approved. Defaults to the current year at add-time. |
| `dateAdded` | `Date` | Not Null | — | Timestamp when the card was added to the wallet. |
| `currency` | `String` | Not Null, default `"USD"` | — | Billing currency code (ISO 4217) for this card. |
| `country` | `String` | Not Null, default `"US"` | — | Country where the card was issued (ISO 3166-1 alpha-2). |
| `status` | `String` | Not Null, default `"active"` | — | Card lifecycle status. Expected values: `"active"`, `"cancelled"`. Cancelled cards are excluded from the wallet display and `CardRateCalculator`, but never deleted (see `CardProductChangeService.cancel`/`reactivate`). |
| `cancelledDate` | `Date?` | Nullable | — | Set when `status` becomes `"cancelled"` — either a manual cancel, or as the first step of `CardProductChangeService.productChange` (which cancels this card and adds a separate new `CreditCard` for the target template — see `CardProductChangeEvent`). Cleared on reactivate. |
| `hasForeignTransactionFee` | `Bool` | Not Null | — | Whether this card charges a foreign transaction fee. |
| `foreignTransactionFeeRate` | `Double?` | Nullable | — | FX fee rate (e.g. `0.03` = 3%). `nil` when `hasForeignTransactionFee` is `false`. |
| `rewards` | `[RewardRate]` | Not Null, cascade delete | 1:N → `RewardRate` (legacy direct relationship) | Legacy reward rates attached directly to the card (pre-plan system). Superseded by `rewardPlans`. |
| `rewardPlans` | `[RewardPlan]` | Not Null, cascade delete | 1:N → `RewardPlan` | All reward plan variants for this card (current, grandfathered, promotional). |
| `selectedPlanID` | `String?` | Nullable | References `RewardPlan.id` | ID of the user's manually selected plan. `nil` = use the plan where `isDefault = true`. |
| `benefits` | `[Benefit]` | Not Null, cascade delete | 1:N → `Benefit` | All benefits attached to this card instance. |
| `allowsCategoryChoice` | `Bool` | Not Null | — | If `true`, the card allows the user to configure which categories its rewards apply to. |
| `availableCategories` | `[String]?` | Nullable | References `SpendingCategory.id` | Category IDs available to choose from when `allowsCategoryChoice` is `true`. |
| `note` | `String` | Not Null, default `""` | — | Free-text note the user can attach to the card. Displayed on the card face. |
| `noteIsVisible` | `Bool` | Not Null, default `true` | — | Whether the note is shown on the card face. |
| `noteTextColor` | `String` | Not Null, default `"#FFFFFF"` | — | Hex color string for the note text. |
| `noteBgColor` | `String` | Not Null, default `"#000000"` | — | Hex color string for the note background bubble. |
| `rewardProgramOverride` | `String?` | Nullable | — | User-selected reward program (set via RewardProgramEditorSheet). `nil` = auto mode: `ProgramUpgradeDatabase` upgrades/downgrades the program from `SeedDataProgramUpgrades.json` rules based on trigger cards in the wallet — applied silently at launch, card add, and card delete. Non-nil skips auto changes and template sync of `rewardProgramName`. |
| `hasCustomAnnualFee` | `Bool` | Not Null, default `false` | — | `true` if the user manually edited the annual fee. Prevents sync from overwriting it. |
| `hasCustomForeignFee` | `Bool` | Not Null, default `false` | — | `true` if the user manually edited the FX fee. Prevents sync from overwriting it. |
| `slotSelections` | `[String: String]` | Not Null, default `[:]` | — | Configurable slot ID → user-selected category label (e.g. `"5pct_slot_1"` → `"Groceries"`). Single source of truth for configurable rewards; `reward.categories` is derived from this. |

---

## 3. RewardPlan

**File:** `Features/Rewards/DataModel/RewardPlan.swift`  
**Role:** Groups a set of `RewardRate` records into a named plan. Supports cards that have changed structures over time (e.g. grandfathered vs. current).

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `id` | `String` | Not Null, application PK | — | Stable plan identifier (e.g. `"csr-current-2024"`, `"card-uuid-custom-1"`). |
| `name` | `String` | Not Null | — | Human-readable plan name displayed in the UI (e.g. `"Current Structure (2024+)"`). |
| `isDefault` | `Bool` | Not Null | — | `true` for the plan shown by default. Only one plan per card should be `true`. |
| `isAvailableForNewUsers` | `Bool` | Not Null | — | `false` for grandfathered or legacy plans that are no longer obtainable. |
| `planStartDate` | `Date?` | Nullable | — | When this plan structure became effective. `nil` = no start constraint. |
| `planEndDate` | `Date?` | Nullable | — | When this plan structure ended. `nil` = still current/ongoing. |
| `isCustomPlan` | `Bool` | Not Null, default `false` | — | `true` if the user created this plan manually rather than from the catalog. |
| `isPromo` | `Bool` | Not Null, default `false` | — | `true` for promotional or limited-time plans (e.g. a sign-up bonus rate period). |
| `card` | `CreditCard?` | Nullable | N:1 → `CreditCard` (back-reference) | Back-reference to the owning card. Managed automatically by SwiftData. |
| `rewards` | `[RewardRate]` | Not Null, cascade delete | 1:N → `RewardRate` | The reward rates that make up this plan. |

---

## 4. RewardRate

**File:** `Features/Rewards/DataModel/RewardRate.swift`  
**Role:** A single earning rule for a card plan. Defines the rate, the reward program, and all scope constraints (category, merchant, country, channel, time).

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `rate` | `Double` | Not Null | — | Earn multiplier (e.g. `3.0` = 3×, `0.01` = 1%). |
| `rewardProgramName` | `String` | Not Null | — | Name of the reward program (e.g. `"Ultimate Rewards"`, `"Cash Back"`). |
| `pointCashValue` | `Double` | Not Null, default `0.01` | — | Estimated cash value per point/mile in `pointCashValueCurrency` (e.g. `0.0125` = 1.25¢/pt). |
| `pointCashValueCurrency` | `String` | Not Null, default `"USD"` | — | Currency for `pointCashValue` (ISO 4217). |
| `categories` | `[String]?` | Nullable | References `SpendingCategory.id` | Category IDs where this rate applies. `nil` = all categories (catch-all/base rate). |
| `merchantIdentifier` | `String?` | Nullable | — | Stable merchant slug (e.g. `"amazon"`, `"mcdonalds"`). When set, this rate applies only at that merchant. |
| `merchantName` | `String?` | Nullable | — | Display-friendly merchant name (e.g. `"Amazon"`). Paired with `merchantIdentifier`. |
| `countries` | `[String]?` | Nullable | — | ISO 3166-1 alpha-2 country codes where this rate is valid. `nil` = all countries. |
| `channels` | `[String]?` | Nullable | — | Purchase channel restrictions. Values: `"online"`, `"in_store"`, `"in_app"`. `nil` = all channels. |
| `rewardStartDate` | `Date?` | Nullable | — | Date this rate becomes active. `nil` = no start restriction. |
| `rewardEndDate` | `Date?` | Nullable | — | Date this rate expires. `nil` = ongoing. |
| `isRotating` | `Bool` | Not Null, default `false` | — | `true` for quarterly rotating category cards (e.g. Discover it). |
| `daysOfWeek` | `[Int]?` | Nullable, values 1–7 | — | Days of the week this rate applies (1 = Sunday … 7 = Saturday). `nil` = all days. |
| `rewardNotes` | `String?` | Nullable | — | Callout text for caps or special conditions (e.g. `"Up to $25k/year"`). |
| `groupLabel` | `String?` | Nullable | — | Display-only group name for non-configurable grouped rewards (e.g. `"Self-Care"`). Shown in earning-rate rows instead of the category name. **Never used for matching** — the pricing engine matches on `categories` only. Added in schema v1.11. |
| `isUserConfigurable` | `Bool` | Not Null, default `false` | — | `true` if the user must select a category for this reward slot. |
| `configurableSlot` | `String?` | Nullable | — | Stable slot identifier (e.g. `"5pct_slot_1"`). Links this rate to the card's `slotSelections` map. |
| `configurableOptions` | `[String]?` | Nullable | — | Display labels the user can pick from (e.g. `["Groceries", "Gas", "Dining"]`). |
| `configurableIncludes` | `[String: [String]]?` | Nullable | References `SpendingCategory.id` (values) | Maps each option label → array of `SpendingCategory.id`s it covers (e.g. `"Groceries"` → `["groceries", "supermarkets"]`). |
| `selectedConfigurableLabel` | `String?` | Nullable | — | The label the user picked (e.g. `"Restaurants"`). Stored for reliable persistence alongside `slotSelections`. |
| `hasCustomPointValue` | `Bool` | Not Null, default `false` | — | `true` if the user set a custom valuation. Prevents `CardSyncService` from overwriting `pointCashValue`. |

---

## 5. Benefit

**File:** `Features/Benefit/DataModel/Models/Benefit.swift`  
**Role:** A single cardholder benefit instance (e.g. "$300 travel credit", "Priority Pass lounge access") attached to a specific card instance.

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `id` | `String` | Not Null, application PK | — | Composite key: `"\(cardInstanceID)_\(templateID)"`. Ties this benefit to one card instance. |
| `benefitType` | `String` | Not Null | — | Backend benefit category (e.g. `"credit"`, `"insurance"`, `"lounge_access"`, `"protection"`, `"voucher"`). |
| `displayGroup` | `String` | Not Null | — | UI grouping label (e.g. `"travel"`, `"dining"`, `"lifestyle"`, `"protection"`, `"membership"`). |
| `localized` | `[String: LocalizedStrings]` | Not Null | — | Dictionary of locale key → `{name, description}`. Keys: `"en"`, `"zh-Hans"`, `"zh-Hant-HK"`, `"zh-Hant-TW"`. Resolution (`displayName`/`displayDescription` in `Benefit_LocalizedStrings.swift`) goes through the shared `AppLocale.localePriorityKeys(for:)` fallback chain — same helper `SpendingCategory.displayName` uses — instead of resolving independently. |
| `value` | `Int` | Not Null, default `0` | — | Monetary value of the benefit in `valueCurrency`. `0` for non-monetary benefits. |
| `valueCurrency` | `String` | Not Null, default `"USD"` | — | Currency of `value` (ISO 4217). |
| `calendarMonthOverrides` | `[Int: Int]?` | Nullable, keys 1–12 | — | Per-calendar-month value overrides (key = month number, value = override amount). |
| `frequency` | `String` | Not Null | — | Reset cadence. Values: `"monthly"`, `"quarterly"`, `"semi-annual"`, `"annual"`, `"quadrennial"`, `"one-time"`, `"ongoing"`. |
| `isRecurring` | `Bool` | Not Null | — | `true` if the benefit resets periodically; `false` for one-time or ongoing (non-resetting) benefits. |
| `resetType` | `String` | Not Null, default `"calendar"` | — | Reset clock anchor. `"calendar"` = resets on Jan 1 / period start; `"card_anniversary"` = resets on card approval anniversary. |
| `usageLimit` | `Int?` | Nullable | — | Maximum redemptions per period. `nil` = value-based (dollar budget). `-1` = unlimited count-based. |
| `validCountries` | `[String]?` | Nullable | — | Countries where benefit is redeemable. `nil` = worldwide. |
| `excludedCountries` | `[String]?` | Nullable | — | Countries where benefit cannot be redeemed. |
| `trackingMode` | `String` | Not Null, default `"manual"` | — | How usage is tracked. Values: `"manual"`, `"auto"`, `"recurring"`. |
| `autoApplyUntil` | `Date?` | Nullable | — | End date for automatic usage application. |
| `autoApplyEnabled` | `Bool` | Not Null, default `false` | — | `true` if user opted into automatic benefit tracking for this benefit. |
| `autoApplyAmount` | `Int?` | Nullable | — | Custom amount to auto-apply each period. `nil` = full remaining value. |
| `expirationDate` | `Date?` | Nullable | — | Hard expiry date for the benefit itself (distinct from periodic reset). |
| `partnerName` | `String?` | Nullable | — | Partner or merchant name (e.g. `"Priority Pass"`, `"Uber"`, `"Plaza Premium"`). |
| `partnerID` | `String?` | Nullable | — | Stable partner/merchant identifier for future cross-reference. |
| `redemptionMethod` | `String?` | Nullable | — | How to redeem (e.g. `"automatic"`, `"statement_credit"`, `"portal_booking"`, `"call_concierge"`, `"mobile_app"`). |
| `limitDescription` | `String?` | Nullable | — | Human-readable limit callout (e.g. `"Up to 6 visits/year"`, `"Max $600 per claim"`). |
| `referenceLink` | `String?` | Nullable | — | URL to the benefit detail page on the issuer's website. |
| `benefitNotes` | `String?` | Nullable | — | Important user-facing callouts (e.g. enrollment requirements, exclusions). |
| `displayOrder` | `Int` | Not Null, default `0` | — | Sort position within the `displayGroup`. |
| `iconName` | `String?` | Nullable | — | Custom icon identifier for the benefit row. |
| `isActive` | `Bool` | Not Null, default `true` | — | Master visibility toggle. `false` = benefit is hidden everywhere. |
| `activeFromDate` | `Date?` | Nullable | — | Benefit becomes visible on or after this date. `nil` = no start constraint. |
| `activeToDate` | `Date?` | Nullable | — | Benefit is hidden after this date. `nil` = no end constraint. |
| `activationDelayPeriods` | `Int?` | Nullable | — | Number of billing periods that must pass after card approval before the benefit unlocks. |
| `activationMode` | `String` | Not Null, default `"unlock"` | — | Access gate. `"unlock"` = always available; `"lockonce"` = requires one-time user activation; `"lockbyfrequency"` = re-activate each period. |
| `activationInstructions` | `String?` | Nullable | — | Instructions displayed when activation is required (e.g. `"Enroll via the CLEAR website"`). |
| `isActivatedByUser` | `Bool` | Not Null, default `false` | — | Permanent unlock flag for `"lockonce"` mode. |
| `activatedAt` | `Date?` | Nullable | — | Timestamp of the user's last activation. Used by `"lockbyfrequency"` to validate current period. |
| `isMuted` | `Bool` | Not Null (`@Attribute`), default `false` | — | Suppresses reminder notifications for this specific benefit. |
| `usageHistory` | `[BenefitUsageRecord]` | Not Null, cascade delete | 1:N → `BenefitUsageRecord` | Full redemption history for this benefit. |

---

## 6. BenefitUsageRecord

**File:** `Features/Benefit/DataModel/Models/BenefitUsageRecord.swift`  
**Role:** One immutable event record per redemption. Provides an auditable log of when and how much of a benefit was used.

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `id` | `String` | `@Attribute(.unique)`, Not Null | — | UUID string. Enforced unique by SwiftData at the store level. Default: `UUID().uuidString`. |
| `redeemedAt` | `Date` | Not Null | — | Wall-clock timestamp of the redemption event. Defaults to `Date.current()` (mockable in tests). |
| `periodKey` | `String` | Not Null | — | Stable string key for the billing period (e.g. `"2025-Q2"`, `"2025-06"`, `"2025-H1"`, `"2025"`). Stored to avoid re-running date math on every read. |
| `redeemedAmount` | `Int` | Not Null | — | Dollar value redeemed (for value-based benefits) or count incremented (for count-based benefits with `usageLimit` set). |
| `isFullyRedeemed` | `Bool` | Not Null, default `false` | — | Snapshot flag: `true` when cumulative redemptions for the period reached the budget at log time. Stored to preserve historical accuracy even if benefit values change later. |
| `benefit` | `Benefit?` | Nullable | N:1 → `Benefit` (back-reference) | Back-reference to the owning benefit. Set automatically by SwiftData when appended to `Benefit.usageHistory`. |
| `notes` | `String?` | Nullable | — | Optional free-text note the user can attach to a redemption event. |
| `source` | `String?` | Nullable | — | How the record was created. Values: `"manual"`, `"auto"`, `"imported"`. |
| `externalID` | `String?` | Nullable | — | Stable external identifier for idempotent import or future iCloud sync de-duplication. |

---

## 7. CardProductChangeEvent

**File:** `Features/Cards/DataModel/CardProductChangeEvent.swift`  
**Role:** One immutable row per Product Change. A Product Change is modeled as **cancel the old card, add a new one** (`CardProductChangeService.productChange`) rather than an in-place mutation — this event is the only link between the two otherwise-independent `CreditCard` rows. Powers the Card History timeline and the "previously X" note shown on the new card's Card Information. Never mutated or deleted after creation. Included in the cloud backup as `CardProductChangeEventBackup` since backup v3, restored independently of the cards it references (`BackupRestoreService.applyProductChangeEvents`).

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `id` | `String` | Not Null, application PK (UUID) | — | Default: `UUID().uuidString`. |
| `fromCardID` | `String` | Not Null | References `CreditCard.id` | The old wallet card instance, which `productChange` cancels (`status = "cancelled"`) but never deletes — it keeps its own real benefits/reward plans/usage history, unchanged. **Exception:** if `fromCardID` was itself created by a same-*calendar-day* product change (i.e. it's the `toCardID` of another event dated today), it's treated as a same-day correction — that intermediate card and its event are deleted outright, and this event links back to the original card instead, collapsing the chain to a single hop. |
| `toCardID` | `String` | Not Null | References `CreditCard.id` | The new wallet card instance, built the same way the normal Add Card flow builds one, with `approvedMonth`/`Day`/`Year` copied from `fromCardID` so the real-world account age is preserved. `dateAdded`/`note` are not copied — they start fresh. |
| `fromTemplateID` | `String` | Not Null | References `CardDatabase` (static JSON, not persisted) | The template `fromCardID` was using. `"unknown"` if it had no `templateID`. |
| `toTemplateID` | `String` | Not Null | References `CardDatabase` (static JSON, not persisted) | The template `toCardID` was created from — matches `toCardID.templateID`. |
| `changeDate` | `Date` | Not Null | — | When the Product Change occurred. |

---

## 8. SpendingCategory

**File:** `Features/Rewards/View/SpendingCategory.swift`  
**Role:** The master taxonomy of merchant categories. Loaded from JSON seed data. Used for reward matching, Earning Power calculations, and the category picker UI.

| Field | Type | Constraints | Relationship | Description |
|---|---|---|---|---|
| `id` | `String` | Not Null, application PK (stable slug) | — | Stable category identifier (e.g. `"dining"`, `"flights"`, `"delta-airlines"`). Never changes; used as a cross-model foreign key. |
| `nameEN` | `String` | Not Null | — | English display name (e.g. `"Dining"`). |
| `nameZH_Hans` | `String` | Not Null | — | Simplified Chinese display name (Mainland). |
| `nameZH_HK` | `String` | Not Null | — | Traditional Chinese display name (Hong Kong). |
| `nameZH_TW` | `String` | Not Null | — | Traditional Chinese display name (Taiwan). |
| `emoji` | `String` | Not Null | — | Emoji icon for the category (e.g. `"🍽️"`). |
| `iconName` | `String?` | Nullable | — | Asset catalog name for a merchant logo (e.g. `"hilton"`, `"mcdonalds"`). Falls back to `emoji` if `nil`. |
| `sortOrder` | `Int` | Not Null | — | Display position for consistent ordering across the picker and Earning Power views. |
| `isActive` | `Bool` | Not Null | — | `false` for deprecated categories that should be hidden everywhere. |
| `isDefault` | `Bool` | Not Null | — | `true` = included in the default category selection for new users. |
| `excludeFromParent` | `Bool` | Not Null | — | `true` = only exact-match rewards apply; parent/ancestor cascade is blocked. Used for merchants like Costco where generic "grocery" cards don't earn. |
| `parentCategoryID` | `String?` | Nullable | Self-referential → `SpendingCategory.id` | Parent category slug (e.g. `"flights"` → `"travel"`). `nil` for top-level parent categories. |
| `level` | `CategoryLevel?` | Nullable, enum | — | Hierarchy level: `parent`, `child`, `groupTarget`, or `target`. |
| `categoryLinksJSON` | `String?` | Nullable, JSON string | Encodes `[CategoryLink]` with refs to `SpendingCategory.id` | Raw JSON storage for additive cross-links (second parent, isolated-brand connection) — hierarchy itself comes from `parentCategoryID`. Encodes as `["amazon"]`; legacy `[{"id":..., "weight":...}]` form still decodes. SwiftData persists as a plain `String`. Access via the computed `categoryLinks` property. |
| `cardFilterJSON` | `String?` | Nullable, JSON string | Encodes `CardFilter` | Raw JSON storage for card eligibility rules (network, issuer, cardType, per-region overrides). Access via the computed `cardFilter` property. |
| `channels` | `[String]?` | Nullable | — | Channel constraints for matching (e.g. `["online"]` for PayPal Pay Anywhere). |
| `excludedPaymentMethods` | `[String]?` | Nullable | — | Payment methods that do NOT work at this merchant (e.g. `["apple_pay", "mobile_pay"]` for Walmart). |
| `visibility` | `String?` | Nullable | — | Display hint. `"hidden"` = suppress from all pickers. `nil` = visible. |

---

## 9. MerchantReward ⚠️ Orphaned

**File:** `Features/Rewards/DataModel/MerchantReward.swift`  
**Role:** Originally intended as a per-card merchant-specific reward override. **Not currently registered in the SwiftData schema** (not included in the `models` list in `Core/Sync/ChurSchema.swift`).

> **Not a bug — a decision that hasn't been made.** Because it is absent from `ChurSchemaV2_0.models`, any instance created would be silently discarded rather than persisted. Two ways out, both requiring a deliberate choice: register it in a **new** `VersionedSchema` (adding a model is a schema change — follow the recipe in `ChurSchema.swift`), or delete the file if `RewardRate.merchantIdentifier` has superseded it. Leaving it as-is is safe; the risk is only that someone assumes it works. See audit note 4.

| Field | Type | Constraints | Description |
|---|---|---|---|
| `merchantName` | `String` | Not Null | Merchant display name (e.g. `"Amazon"`, `"Whole Foods"`). |
| `rate` | `Double` | Not Null | Earn rate (e.g. `5.0` for 5%). |
| `pointType` | `String` | Not Null | Reward currency type (e.g. `"Cash"`, `"UR"`, `"MR"`). |
| `isTemporary` | `Bool` | Not Null, default `false` | `true` for limited-time Amex Offers / targeted promos. |
| `startDate` | `Date?` | Nullable | When the offer started. |
| `endDate` | `Date?` | Nullable | When the offer expires. |
| `notes` | `String?` | Nullable | Offer description (e.g. `"Amex Offer: Spend $50, get $10 back"`). |
| `merchantCategory` | `String?` | Nullable | Broad category of the merchant (e.g. `"Online Retailer"`, `"Grocery"`). |

---

## 10. In-Memory / Static Structures (not persisted)

These are value types (`struct`) used in-memory only. They are not stored in SwiftData or the cloud backup.

### CardTemplate / PlanTemplate / RewardTemplate
**File:** `Features/Cards/DataModel/CardDatabase.swift`

Lightweight in-memory mirrors of the JSON seed data. `CardDatabase` loads these from the app bundle at startup and holds them in a static cache. They mirror the shape of `CreditCard`, `RewardPlan`, and `RewardRate` respectively.

### BenefitTemplate
**File:** `Features/Benefit/DataModel/Models/BenefitTemplate.swift`

In-memory representation of a benefit from the JSON catalog (`BenefitDatabase`). Mapped to a live `Benefit` @Model via `toBenefit(cardInstanceID:modelContext:)`.

### Merchant seed types
**File:** `Features/Rewards/DataModel/MerchantSeedDatabase.swift` (+ `OnlineMerchantDatabase.swift`)

| Type | Description |
|---|---|
| `MerchantSeedFile` | In-memory aggregate of the merchant seed: all `SeedDataMerchants_<group>.json` files (plain arrays, concatenated at load; grouping is organizational only) + `SeedDataGenericMappings.json`. The **single source** for merchant data. |
| `MerchantEntry` | One merchant: online-search fields, optional `map` matching block, optional `brandCategory` block that auto-generates the target `SpendingCategory` at load (`SeedDataLoader.loadCategoryTemplates`; hand-authored categories win on ID conflict). `searchable: false` = map-only. |
| `MerchantMappings` | Map name-matching rules (exact / prefix+POI / contains+POI / patterns+overrides), consumed by `MerchantCategoryMapper`. Merchant `map` rules are merged in ahead of generic pattern rules. |
| `OnlineMerchant` | Runtime type for the Online search mode, derived from searchable `MerchantEntry`s. |

### SpendingCategory support types

| Type | Fields | Description |
|---|---|---|
| `CategoryLink` | `id: String` | Cross-link to another `SpendingCategory.id` (`weight` removed 2026-07 — it was never read by any consumer). Encodes as a plain string; decodes from string or legacy `{id, weight}` object. Stored as JSON in `SpendingCategory.categoryLinksJSON`. |
| `CardFilter` | `networks`, `issuers`, `cardTypes`, `mode`, `regions` | Card eligibility rules. Supports both global and region-specific filter variants. Stored as JSON in `SpendingCategory.cardFilterJSON`. |
| `LocalizedStrings` | `name: String`, `description: String` | Locale-keyed name + description pair. Stored as values in `Benefit.localized` dictionary. |

---

## 11. Relationships Overview

```
User
 ├── cardDisplayOrder [String]  ──references──▶  CreditCard.id  (ordered list)
 ├── selectedCategories [String] ─references──▶  SpendingCategory.id
 └── boostEnrollments [String:String] ─key──▶   BoostProgram.id (static, not persisted)

CreditCard
 ├── templateID ──────────────references──▶  CardDatabase (static JSON)
 ├── rewards (cascade) ────────1:N──────────▶  RewardRate         [legacy direct]
 ├── rewardPlans (cascade) ────1:N──────────▶  RewardPlan
 │    └── rewards (cascade) ───1:N──────────▶  RewardRate
 └── benefits (cascade) ───────1:N──────────▶  Benefit
      └── usageHistory (cascade) ─1:N────────▶  BenefitUsageRecord

CardProductChangeEvent
 ├── fromCardID ──────────────references──▶  CreditCard.id  (old card, now cancelled)
 ├── toCardID ────────────────references──▶  CreditCard.id  (new card, freshly added)
 ├── fromTemplateID ──────────references──▶  CardDatabase (static JSON)
 └── toTemplateID ────────────references──▶  CardDatabase (static JSON)

SpendingCategory
 └── parentCategoryID ─────self-ref──────────▶  SpendingCategory.id
```

**Cascade behaviour:** Deleting a `CreditCard` deletes all its `RewardPlan`, `RewardRate` (via plan), and `Benefit` records, and all `BenefitUsageRecord` history. The `User` record is never cascade-deleted; it is reset to its `anonymous` defaults instead. `CardProductChangeEvent` rows are not cascade-linked to `CreditCard` (plain string `fromCardID`/`toCardID` references, not SwiftData relationships) — they survive even if either card is later deleted, and are not currently cleaned up in that case (see Audit Notes).

---

## 12. Audit Notes & Risks

| # | Severity | Status | Area | Finding |
|---|---|---|---|---|
| 1 | **High** | ✅ Done | Schema migration | `ChurMigrationPlan` created in `Core/Sync/ChurSchema.swift`; the container is built with `migrationPlan:`. Superseded by note 1b — the plan existed but could not work. The versions named here (`ChurSchemaV1_10` … `V1_14`) no longer exist; the baseline is `ChurSchemaV2_0`. |
| 1b | **High** | ✅ Done (2026-08-11) | Schema migration | Was: every versioned schema referenced the same live `@Model` classes, so staged migration could never run and any model change broke existing stores (confirmed 2026-07-11 adding `groupLabel`). Fixed in three parts: (a) the synthetic v1.10 … v1.14 ladder collapsed into the single frozen baseline `ChurSchemaV2_0`, with the freeze-the-old-shape-first recipe written into the `ChurSchema.swift` header; (b) `SchemaFingerprint` fails a DEBUG assertion when a model changes without a version bump, so the mistake can no longer ship silently; (c) `ChurStoreRecovery` replaces the launch `fatalError` with quarantine-and-restart plus a recovery notice pointing at Drive restore. Recovery verified 2026-08-12 by corrupting a simulator store: failure caught, store quarantined, notice shown, wallet restored from Drive. **Not yet exercised against a real staged migration** — the first one lands with the next model change. |
| 2 | **High** | ✅ Done | Backup versioning | `CloudSyncManager.migrate(_:)` added. `downloadBackup()` runs migration after decode. New DTO fields must be `optional`. Increment `ChurBackup.currentVersion` and add a migration case for each breaking change. |
| 3 | **Medium** | Deferred | Apple backup | Apple Sign In users have no cloud backup. CloudKit planned after Google flow is stable. |
| 4 | **Medium** | Placeholder | `MerchantReward` | Kept as `@Model` placeholder for future use. Not in `ChurSchemaV2_0.models`, so instances would be silently discarded rather than persisted. Registering it is itself a schema change — add a new `VersionedSchema` + stage, don't edit the baseline. |
| 5 | **Medium** | Open | `User.authProvider` | Raw `String` with no enum enforcement. Migrate to `Codable` enum before v1.1. |
| 6 | **Medium** | Open | String closed-value fields | `Benefit.frequency`, `resetType`, `activationMode`, `trackingMode` — no validation layer. Add on-write checks or enum-backed storage. |
| 7 | **Medium** | Open | Dual reward path | Legacy `CreditCard.rewards` (direct) co-exists with `rewardPlans`. Remove once all cards have plans; requires a `MigrationStage`. |
| 8 | **Medium** | Open | `selectedConfigurableLabel` | Redundant with `CreditCard.slotSelections`. Remove to eliminate drift risk. |
| 9 | **Low** | Open | `User.profilePhotoData` | Raw JPEG `Data` inline in model. Add `@Attribute(.externalStorage)` to avoid loading on every `User` fetch — note that is a schema change and needs a new version. Backup size is not a concern: `ProfilePhotoPicker.compress` caps at 400px / quality 0.7, so the base64 payload added to the v3 backup is tens of KB. |
| 10 | **Low** | Open | Hex color strings | `CreditCard.noteTextColor` / `noteBgColor` unvalidated. Add hex-format check on write. |
| 11 | **Info** | Open | `User` singleton | No uniqueness constraint. Add boot-time assertion and a merge/delete repair path. |
| 12 | **Info** | Open | `BenefitUsageRecord` import | Idempotent re-import requires caller-supplied `externalID`; `id` uniqueness alone is insufficient. |
| 13 | **Low** | Open | `CardProductChangeEvent` orphaning | Not cascade-linked to `CreditCard` (see Relationships Overview) — rows survive card deletion with no cleanup path. Low impact today (history-only, never read after its card is gone), but worth a cleanup pass if `CardProductChangeEvent` volume grows. |
| 14 | **Low** | ✅ Done (2026-08-11) | `CardProductChangeEvent` not backed up | Added to `ChurBackup` as `productChangeEvents` in backup v3. Restored via `BackupRestoreService.applyProductChangeEvents`, keyed on `id` so repeated restores stay idempotent. |
| 15 | **Medium** | ✅ Done (2026-08-11) | Backup coverage gaps | Audit of every `@Model` field against the DTOs found seven more silently-dropped values, all fixed in backup v3: `Benefit.autoApplyAmount` (restored auto-apply replayed the **full period budget** instead of the user's amount), `Benefit.isMuted` (muted benefits un-muted and resumed notifications), `User.profilePhotoData`, `User.dateAdded`, `CreditCard.noteTextColor` / `noteBgColor`, `CreditCard.hasCustomImage` (restored `false`, so the next `CardSyncService` pass overwrote user art), `CreditCard.dateAdded`. |
| 16 | **Low** | Open | Custom `RewardPlan` not backed up | `RewardPlan.isCustomPlan` exists and `CardSyncService` explicitly preserves custom plans during sync, but nothing in the app ever sets it to `true` — the feature is scaffolding, so there is no bug today. Whenever custom-plan creation ships, the backup must carry the plan and its rates: restore re-seeds plans from templates, so a custom plan would vanish and `selectedPlanID` would dangle. |
