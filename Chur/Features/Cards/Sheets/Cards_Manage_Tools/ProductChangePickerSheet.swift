//
//  ProductChangePickerSheet.swift
//  Chur
//
//  Card picker for Product Change — same-issuer only, single selection,
//  confirms immediately via CardProductChangeService.productChange.
//

import SwiftUI
import SwiftData

struct ProductChangePickerSheet: View {
    let card: CreditCard

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var pendingTemplate: CardTemplate?

    private var candidates: [CardTemplate] {
        CardDatabase.getAllCards()
            .filter { $0.issuer == card.issuer && $0.id != card.templateID }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    EmptyStatePlaceholder(
                        icon: "creditcard",
                        title: "No Other \(card.issuer) Cards",
                        subtitle: "There are no other \(card.issuer) cards to switch to yet."
                    )
                } else {
                    List(candidates, id: \.id) { template in
                        CardDatabaseRow(template: template, addedCount: 0, onAdd: {
                            pendingTemplate = template
                        })
                        .contentShape(Rectangle())
                        .onTapGesture { pendingTemplate = template }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Switch \(card.name) To")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.churOffWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Switch to \(pendingTemplate?.name ?? "")?", isPresented: Binding(
                get: { pendingTemplate != nil },
                set: { if !$0 { pendingTemplate = nil } }
            )) {
                Button("Switch", role: .destructive) {
                    if let template = pendingTemplate {
                        CardProductChangeService.productChange(card: card, toTemplateID: template.id, modelContext: modelContext)
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { pendingTemplate = nil }
            } message: {
                Text("\(card.name)'s benefits and reward rates will switch to \(pendingTemplate?.name ?? "the new card"). Its approved date, notes, and usage history are kept.")
            }
        }
    }
}
