//
//  DisplaySettingsView.swift
//  Chur
//

import SwiftUI

struct DisplaySettingsView: View {
    @Bindable var user: User

    private var footerText: String {
        user.showEffectiveRate
            ? "Rewards sorted by effective % return per dollar spent."
            : "Rewards sorted by card rate."
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
