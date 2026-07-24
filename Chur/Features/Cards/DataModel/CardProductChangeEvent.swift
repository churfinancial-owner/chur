//
//  CardProductChangeEvent.swift
//  Chur
//

import Foundation
import SwiftData

/// One row per Product Change — records that a wallet card instance (`cardID`) switched
/// from one card template to another on a given date. Powers the "previously X" history
/// display; never mutated or deleted after creation.
@Model
class CardProductChangeEvent {
    var id: String
    var cardID: String
    var fromTemplateID: String
    var toTemplateID: String
    var changeDate: Date

    init(id: String = UUID().uuidString, cardID: String, fromTemplateID: String, toTemplateID: String, changeDate: Date) {
        self.id = id
        self.cardID = cardID
        self.fromTemplateID = fromTemplateID
        self.toTemplateID = toTemplateID
        self.changeDate = changeDate
    }
}
