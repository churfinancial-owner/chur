//
//  BenefitReminderRouter.swift
//  Chur
//
//  Bridges benefit-reminder notification taps into SwiftUI. The
//  UNUserNotificationCenter delegate stores the tapped benefit's IDs on the
//  shared router; ContentView observes them and presents the benefit's
//  detail sheet.
//

import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class BenefitReminderRouter {
    static let shared = BenefitReminderRouter()
    private init() {}

    var pendingBenefitID: String?
    var pendingCardID: String?

    func clear() {
        pendingBenefitID = nil
        pendingCardID = nil
    }
}

/// A resolved notification tap, ready to present as a sheet.
struct BenefitDeepLinkTarget: Identifiable {
    let card: CreditCard
    let benefit: Benefit
    var id: String { "\(card.id).\(benefit.id)" }
}

/// Must be installed before the app finishes launching so taps that
/// cold-start the app are still delivered (see ChurApp.init).
final class BenefitReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = BenefitReminderDelegate()

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
        let benefitID = info["benefitID"] as? String
        let cardID = info["cardID"] as? String

        Task { @MainActor in
            if let benefitID {
                BenefitReminderRouter.shared.pendingBenefitID = benefitID
                BenefitReminderRouter.shared.pendingCardID = cardID
            }
            completionHandler()
        }
    }
}
