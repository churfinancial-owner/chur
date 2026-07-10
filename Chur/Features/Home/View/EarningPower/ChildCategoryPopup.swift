//
//  ChildCategoryPopup.swift
//  Chur
//
//  Created by Pak Ho on 1/25/26.
//

import SwiftUI
import SwiftData

struct CategoryDetailSheetParallax: View {
    let category: SpendingCategory
    let parentCategory: SpendingCategory?
    let rate: Double
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let currentRegionCodeOverride: String?

    var body: some View {
        ParentCategoryParallaxSheet(
            category: category,
            rate: rate,
            cards: cards,
            allCategories: allCategories,
            currentRegionCodeOverride: currentRegionCodeOverride,
            headerLabel: "SUB-CATEGORY",
            showRelatedCategories: false
        )
    }
}
