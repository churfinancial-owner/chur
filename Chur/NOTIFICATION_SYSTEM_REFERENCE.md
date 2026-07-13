# Notification System Reference

How Chur's local reminder notifications work. Read this before touching
anything under `Features/Benefit/Service/Reminder*` or the Notifications
settings screens. **Update this file whenever a reminder category, timing
rule, or routing behavior changes.**

Built July 2026. All notifications are **local** (scheduled on-device via
`UNUserNotificationCenter`) — there is no server push / APNs.

---

## 1. The one idea that matters: reconciliation

Local notifications are scheduled ahead of time, so any state change
(usage logged, benefit muted, card deleted, setting changed) can leave a
stale notification that fires anyway — the #1 amateur-app failure.

Chur never schedules imperatively. `ReminderScheduler.reconcile(context:)`
always:

1. Recomputes the **full desired set** of reminders from current SwiftData
   state across all enabled categories.
2. Collapses same-day pileups into a digest (see §4).
3. Diffs against what's pending in `UNUserNotificationCenter`:
   stale requests are cancelled; every desired reminder is (re-)added.
   Re-adding an existing identifier *replaces* it, which refreshes copy
   like remaining balances.

**Reconcile triggers:** scenePhase `.active` and `.background`
(`ContentView`), settings toggles and timing pickers
(`NotificationSettingsView`, `ReminderScheduleView`), leaving the
notifications settings screen (picks up mute changes).

If you add a code path that changes what should be reminded, you don't
schedule anything — you call
`ReminderScheduler.shared.requestReconcile(context:)`.

---

## 2. Categories

| Kind (`ReminderKind`) | Planner | Toggle key (UserDefaults) | Tap routing |
|---|---|---|---|
| `benefitExpiry` | `ReminderScheduler.swift` | `benefitRemindersEnabled` | Benefit detail sheet |
| `annualFee` | `ReminderScheduler_AnnualFee.swift` | `annualFeeRemindersEnabled` | Cards tab |
| `digest` | `ReminderScheduler_Digest.swift` (derived, no toggle) | — | Expiring Soon sheet (`ExpiringBenefitsView`) |

**Benefit expiry** — one reminder per benefit per period per lead time.
Skipped when: benefit inactive, not `isRemindable` (ongoing/unlimited),
muted, locked/delayed, fully redeemed this period, one-time benefit with
any usage history, or card not `status == "active"`.

**Annual fee** — fee date is the card anniversary
(`approvedMonth`/`approvedDay`, next occurrence). Skipped when
`annualFee == 0` (so downgrading a card via the custom fee field silences
it naturally) or card inactive.

---

## 3. Timing — `ReminderTiming` is the single source of truth

**One lead time for all benefit frequencies** and one for the annual fee
(simplified for MVP, 2026-07-12). The benefit lead drives **both** the
in-app warning window (⏰ badge, red expiry highlight, "Expiring" filter,
card-tab alarm, Expiring Soon sheet) and the notification schedule. Never
read a lead time from anywhere else; never hardcode day counts in views.

| Category | Options (days) | Default | Reminders per period |
|---|---|---|---|
| Benefits (every frequency) | 1 / 3 / 7 | 7 | 1 — no last calls |
| Annual fee | 0 (fee day) / 7 / 14 | 0 | 1 — no last calls |

Rules:

- Stored in UserDefaults (`reminderLead.benefits`, `reminderLead.annualFee`)
  — device-local, not synced, no schema impact. (The abandoned per-cycle
  keys `reminderLead.<cycle>` are ignored.)
- Delivery is at 9 AM local (`ReminderScheduler.deliveryHour`).
- `ReminderTiming.isInWarningWindow(expiry:now:)` is the one question
  views ask; planners read `benefitLeadDays` / `annualFeeLeadDays`.
- `isRecommended` / `resetToRecommended()` back the "Recommended/Custom"
  label and reset button in settings.

---

## 4. Anti-spam digest

Calendar pileups are structural: at month end every monthly benefit hits
its window the same morning; quarter/year ends stack cycles. Rule:

- **3+ benefit reminders on the same day** (`digestThreshold`) collapse
  into one summary: *"N benefits expiring soon — $X unused across M
  cards."* Only the trigger counts the day's batch; the body's numbers are
  the **full in-window picture at the fire date**, computed by
  `ExpiringBenefits` — the same query the Expiring Soon sheet runs — so the
  notification always matches the sheet it opens. The unused total is only
  quoted when all values share one currency (computed at reconcile time, so
  redemptions between reconcile and 9 AM can leave it slightly stale).
- **Fee reminders are never digested** — rare and high-stakes.
- Digest identifier is per-day (`churReminder.digest.<yyyy-MM-dd>`), so
  reconciliation diffs it like any other reminder.

---

## 5. Identifiers & payloads

Everything the scheduler owns is prefixed `churReminder.`
(legacy `benefitReminder.` is still cleaned up in diffs):

```
churReminder.benefit.<cardID>.<benefitID>.<periodKey>.<lead>d
churReminder.fee.<cardID>.<feeYear>.<lead>d
churReminder.digest.<yyyy-MM-dd>
```

- **Card ID is part of benefit identifiers because benefit IDs come from
  templates and repeat across cards.** Any lookup must match card first.
- The period key makes benefit reminders per-period stable; next period's
  reminders appear automatically on reconcile.
- Every payload carries `kind` (a `ReminderKind` raw value) plus
  `benefitID`/`cardID` as needed. `threadIdentifier` is the card ID so
  Notification Center groups per card.

---

## 6. Tap routing & permission

- `ChurNotificationDelegate` (in `ReminderRouter.swift`) is the app's
  **single** `UNUserNotificationCenter` delegate, installed in
  `ChurApp.init` (must be before launch finishes so cold-start taps
  work). It dispatches on `kind` and writes to `ReminderRouter.shared`;
  `ContentView` observes the router and navigates (benefit → detail
  sheet via `BenefitDeepLinkTarget`/`BenefitReminderDeepLinkSheet`;
  fee → Cards tab; digest → `ExpiringBenefitsView` sheet, a global list
  of benefits in their warning window with balance left, grouped by
  card, row tap opens the benefit detail sheet).
- Permission is requested **in context** — when a user enables a toggle
  in Notification settings, never at launch. Denied → toggle reverts +
  alert deep-linking to iOS Settings. A revoked-permission warning row
  appears if a toggle is on but authorization is missing.
- Foreground notifications present as banner + sound.

---

## 7. Settings UX invariants

`NotificationSettingsView` (main) → `ReminderScheduleView` (subpage):

- All sections stay visible regardless of toggles — timing and mutes also
  drive in-app badges, so hiding them would be misleading.
- Main screen: per-category toggles, one "Reminder Schedule" row showing
  "Recommended"/"Custom", per-card mute list (collapsed by default).
- Per-benefit mute (`Benefit.isMuted`) affects both notifications and
  badges, and is also reachable from the benefit detail sheet.

---

## 8. Hard constraints & gotchas

- **iOS caps pending local notifications at 64 per app.** The reconciler
  keeps the soonest 60 (`maxPendingReminders`) across all categories.
  Never schedule outside the reconciler or the budget breaks.
- Planners use `Date.current()` (time-travel/test mockable), but fire
  dates are real-world calendar dates.
- Notification copy is English-only for now (matches app chrome;
  `displayName` is localized). Localize when app chrome localizes.
- The real notification switches are UserDefaults keys (see §2/§3) — there
  is no SwiftData field (`User.notificationsEnabled` was removed in schema
  v1.12).
- Delivered-but-unread notifications are not cleared from Notification
  Center when they become stale (only *pending* ones are cancelled).

## 9. Adding a new category (e.g. card recommendations)

1. Add a case to `ReminderKind` and a toggle key on `ReminderScheduler`.
2. Write a planner in `ReminderScheduler_<Category>.swift` returning
   `[PlannedReminder]` with a new identifier segment
   (`churReminder.<segment>.…`) and `kind` in the payload.
3. Include it in `reconcile(context:)` behind its toggle.
4. Add the toggle to `NotificationSettingsView` (reuse `handleToggle`)
   and, if it has timing, a row in `ReminderScheduleView` +
   `ReminderTiming`.
5. Add a routing case to `ChurNotificationDelegate` / `ReminderRouter` /
   `ContentView.consumePendingReminderTap()`.
6. Decide digest interaction (default: not digested).
7. Update this file.

## 10. Known follow-ups

- Notification quick actions ("Mark as used", "Mute").
- Localized notification copy (4 locales).
- Remote push (APNs) would be an entirely separate stack — nothing here
  assumes a server.
