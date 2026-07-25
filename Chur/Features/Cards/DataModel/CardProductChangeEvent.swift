//
//  CardProductChangeEvent.swift
//  Chur
//

import Foundation
import SwiftData

/// One row per Product Change. A Product Change cancels the old wallet card instance
/// (`fromCardID`) and creates a brand-new one (`toCardID`) from the target template —
/// it does not mutate a card in place. This event is the only link between the two
/// otherwise-independent `CreditCard` rows, and powers the Card History timeline and
/// the "previously X" note on the new card. Never mutated or deleted after creation.
@Model
class CardProductChangeEvent {
    var id: String
    var fromCardID: String
    var toCardID: String
    var fromTemplateID: String
    var toTemplateID: String
    var changeDate: Date

    init(id: String = UUID().uuidString, fromCardID: String, toCardID: String, fromTemplateID: String, toTemplateID: String, changeDate: Date) {
        self.id = id
        self.fromCardID = fromCardID
        self.toCardID = toCardID
        self.fromTemplateID = fromTemplateID
        self.toTemplateID = toTemplateID
        self.changeDate = changeDate
    }
}
