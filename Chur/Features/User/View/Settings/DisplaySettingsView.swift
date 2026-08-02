//
//  DisplaySettingsView.swift
//  Chur
//

import SwiftUI

struct DisplaySettingsView: View {
    @Bindable var user: User

    private var footerText: String {
        // Text(_:) with a plain String argument is displayed verbatim (no catalog
        // lookup) — String(localized:) resolves the translation first so the
        // literals below are still eligible for the String Catalog.
        user.showEffectiveRate
            ? String(localized: "Rewards sorted by effective % return per dollar spent.", locale: AppLocale.current)
            : String(localized: "Rewards sorted by card rate.", locale: AppLocale.current)
    }

    var body: some View {
        List {
            Section {
                Picker("Reward Display", selection: $user.showEffectiveRate) {
                    Text("Card Rate (4x)").tag(false)
                    Text("Effective Rate (5%)").tag(true)
                }
                .pickerStyle(.inline)
                .tint(Color.churOlive)
            } header: {
                Text("Reward Display Mode")
            } footer: {
                Text(footerText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Display")
        .navigationBarTitleDisplayMode(.inline)
    }
}
