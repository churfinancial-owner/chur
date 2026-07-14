//
//  ReminderRouter.swift
//  Chur
//
//  Bridges notification taps into SwiftUI. ChurNotificationDelegate reads
//  the tapped notification's "kind" and stores a destination on the shared
//  router; ContentView observes it and navigates:
//   • benefitExpiry → that benefit's detail sheet
//   • annualFee     → the Cards tab, scrolled to that card
//   • digest        → the global Expiring Soon sheet
//

import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class ReminderRouter {
    static let shared = ReminderRouter()
    private init() {}

    var pendingBenefitID: String?
    var pendingCardID: String?
    var pendingCardsTab = false
    var pendingExpiringList = false

    /// Card to scroll the wallet carousel to once the Cards tab appears
    /// (annual fee taps). Kept out of clear() — it must survive past
    /// ContentView's tab switch until CardsView consumes it.
    var pendingScrollToCardID: String?

    func clear() {
        pendingBenefitID = nil
        pendingCardID = nil
        pendingCardsTab = false
        pendingExpiringList = false
    }
}

/// A resolved notification tap, ready to present as a sheet.
struct BenefitDeepLinkTarget: Identifiable {
    let card: CreditCard
    let benefit: Benefit
    var id: String { "\(card.id).\(benefit.id)" }
}

/// The app's single UNUserNotificationCenter delegate, dispatching taps by
/// the "kind" field each category stamps into its payload. Must be installed
/// before the app finishes launching so taps that cold-start the app are
/// still delivered (see ChurApp.init).
final class ChurNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ChurNotificationDelegate()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Show reminders as banners even while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let kind = ReminderKind(rawValue: info["kind"] as? String ?? "")
        let benefitID = info["benefitID"] as? String
        let cardID = info["cardID"] as? String

        Task { @MainActor in
            switch kind {
            case .benefitExpiry:
                if let benefitID {
                    ReminderRouter.shared.pendingBenefitID = benefitID
                    ReminderRouter.shared.pendingCardID = cardID
                }
            case .annualFee:
                ReminderRouter.shared.pendingCardsTab = true
                ReminderRouter.shared.pendingScrollToCardID = cardID
            case .digest:
                ReminderRouter.shared.pendingExpiringList = true
            case nil:
                break
            }
            completionHandler()
        }
    }
}
