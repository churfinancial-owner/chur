//
//  PaymentMethods.swift
//  Chur
//
//  P1f part 3. Payment method is a transaction dimension, like channel and
//  currency: a reward row or a layer names the methods it applies to (or, for
//  a layer, excludes), and the pricing context says which methods this purchase
//  could be made with. These ids are the vocabulary. Each also has a hidden
//  category in `SeedDataCategories_payment.json` for its display name, and the
//  legacy form — a payment id inside a reward's `categories` — still works as a
//  compatibility shim (matchWeight step 3).
//

import Foundation

enum PaymentMethods {
    static let mobilePay = "mobile_pay"
    static let applePay = "apple_pay"
    static let paypal = "paypal_pay"
    static let contactless = "contactless"
    static let unionPayQuickPass = "unionpay_quickpass"
    static let alipayHK = "alipay_hk"
    static let wechatPayHK = "wechat_pay_hk"

    static let all: Set<String> = [
        mobilePay, applePay, paypal, contactless, unionPayQuickPass, alipayHK, wechatPayHK
    ]

    /// Display name, from the matching hidden category when the caller has the
    /// category list (localized), else a plain fallback.
    static func displayName(_ id: String, categories: [SpendingCategory] = []) -> String {
        if let category = categories.first(where: { $0.id == id }) { return category.displayName }
        switch id {
        case mobilePay:         return "Mobile Pay"
        case applePay:          return "Apple Pay"
        case paypal:            return "PayPal"
        case contactless:       return "Contactless"
        case unionPayQuickPass: return "UnionPay QuickPass"
        case alipayHK:          return "AlipayHK"
        case wechatPayHK:       return "WeChat Pay HK"
        default:                return id
        }
    }
}
