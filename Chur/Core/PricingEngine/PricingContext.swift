//
//  PricingContext.swift
//  Chur
//
//  Everything about *this* purchase that the pricing engine needs, in one value:
//  where it happens, how it is paid, and what the user has enrolled in. Cards and
//  categories are inputs to the calculator; the context is the transaction.
//
//  P1f part 1. Later parts add the derived transaction currency and the
//  payment-method dimension here rather than as more init parameters.
//

import Foundation

struct PricingContext {
    /// The spending category the merchant resolved to.
    let category: SpendingCategory
    /// Merchant region code (e.g. "US", "HK"). nil = global merchant: no FX for any card.
    let region: String?
    /// "in_store", "online", or nil (all channels). `online` also switches on the
    /// `online_transactions` overlay.
    let channel: String?
    /// programID → the user's selection for that program (tier, allocation or pick).
    let boostEnrollments: BoostEnrollments
    /// When false, payment-method rewards (mobile_pay, apple_pay, …) never match as a fallback.
    let allowPaymentMethodFallback: Bool
    /// Treat the purchase as cross-border for every card regardless of region.
    let forceCrossBorder: Bool
    /// When set, payment-method rewards apply only for the listed methods.
    let acceptedPaymentMethods: Set<String>?
    /// Regions the merchant operates in. Overrides `region` for cross-border detection when set.
    let acceptedRegions: Set<String>?

    init(
        category: SpendingCategory,
        region: String? = nil,
        channel: String? = nil,
        boostEnrollments: BoostEnrollments = [:],
        allowPaymentMethodFallback: Bool = true,
        forceCrossBorder: Bool = false,
        acceptedPaymentMethods: Set<String>? = nil,
        acceptedRegions: Set<String>? = nil
    ) {
        self.category = category
        self.region = region
        self.channel = channel
        self.boostEnrollments = boostEnrollments
        self.allowPaymentMethodFallback = allowPaymentMethodFallback
        self.forceCrossBorder = forceCrossBorder
        self.acceptedPaymentMethods = acceptedPaymentMethods
        self.acceptedRegions = acceptedRegions
    }

    var isOnline: Bool { channel == "online" }
}
