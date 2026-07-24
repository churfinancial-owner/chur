import SwiftUI
import SwiftData

struct CardInformationSection: View {
    @Bindable var card: CreditCard
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    @State private var showingStatusActions = false
    @State private var showingCancelConfirm = false

    @Query private var productChangeEvents: [CardProductChangeEvent]

    init(card: CreditCard, activeSheet: Binding<CardInfoContentView.ActiveSheet?>) {
        self.card = card
        self._activeSheet = activeSheet
        let cardID = card.id
        self._productChangeEvents = Query(
            filter: #Predicate<CardProductChangeEvent> { $0.cardID == cardID },
            sort: \CardProductChangeEvent.changeDate,
            order: .reverse
        )
    }

    private var currentNetworkLabel: String { Self.networkOptionLabel(from: card.network) }
    private var currentCardTypeLabel: String { Self.cardTypeDisplayLabel(for: card.cardType) }
    private var statusDisplay: String { card.status == "cancelled" ? "Cancelled" : "Active" }
    private var previousProductLabel: String? {
        guard let latest = productChangeEvents.first,
              let fromTemplate = CardDatabase.getCard(id: latest.fromTemplateID) else { return nil }
        return "Previously \(fromTemplate.name) until \(latest.changeDate.formatted(.dateTime.month().day().year()))"
    }

    var approvedDateDisplay: String {
        let components = DateComponents(year: card.approvedYear, month: card.approvedMonth, day: card.approvedDay)
        if let date = Calendar.current.date(from: components) {
            return date.formatted(.dateTime.month().day().year())
        }
        return "\(card.approvedMonth)/\(card.approvedDay)/\(card.approvedYear)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardSectionHeader(title: "CARD INFORMATION")

            VStack(spacing: 0) {
                DetailRow(label: "Issuer", value: card.issuer, isEditable: false)
                CardRowDivider()
                DetailRow(label: "Card Name", value: card.name, isEditable: false)
                CardRowDivider()
                DetailRow(label: "Network", value: currentNetworkLabel, isEditable: true) {
                    activeSheet = .network
                }
                CardRowDivider()
                DetailRow(label: "Card Type", value: currentCardTypeLabel, isEditable: true) {
                    activeSheet = .cardType
                }
                CardRowDivider()
                DetailRow(label: "Approved Date", value: approvedDateDisplay, isEditable: true) {
                    activeSheet = .approvedDate
                }
                CardRowDivider()
                DetailRow(label: "Status", value: statusDisplay, isEditable: true) {
                    showingStatusActions = true
                }
                if let previousProductLabel {
                    Text(previousProductLabel)
                        .font(.churSmall())
                        .foregroundStyle(Color.churMediumGray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Card Status", isPresented: $showingStatusActions, titleVisibility: .visible) {
            if card.status == "cancelled" {
                Button("Reactivate Card") {
                    CardProductChangeService.reactivate(card: card)
                }
            } else {
                Button("Product Change") {
                    activeSheet = .productChangePicker
                }
                Button("Cancel Card", role: .destructive) {
                    showingCancelConfirm = true
                }
            }
        }
        .alert("Cancel \(card.name)?", isPresented: $showingCancelConfirm) {
            Button("Cancel Card", role: .destructive) {
                CardProductChangeService.cancel(card: card)
            }
            Button("Keep Card", role: .cancel) {}
        } message: {
            Text("This removes the card from your wallet and reward calculations. Its history is kept — you can reactivate it later from Closed Cards.")
        }
    }

    // MARK: - Static Formatting Logic

    static func networkOptionLabel(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        switch normalized {
        case "americanexpress", "amex": return "Amex"
        case "mastercard", "mc":        return "Mastercard"
        case "visa":                    return "Visa"
        case "discover":                return "Discover"
        case "jcb":                     return "JCB"
        case "unionpay", "union pay":   return "UnionPay"
        default: return trimmed.isEmpty ? "Visa" : trimmed
        }
    }

    static func cardTypeOptionValue(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        switch normalized {
        case "personal":                          return "personal"
        case "business":                          return "business"
        case "student":                           return "student"
        case "authorized_user", "authorizeduser": return "authorized_user"
        default: return trimmed.isEmpty ? "personal" : normalized
        }
    }

    static func cardTypeDisplayLabel(for option: String) -> String {
        switch option {
        case "personal":        return "Personal"
        case "business":        return "Business"
        case "student":         return "Student"
        case "authorized_user": return "Authorized User"
        default: return option.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
