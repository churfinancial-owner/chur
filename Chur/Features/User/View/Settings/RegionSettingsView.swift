//
//  RegionSettingsView.swift
//  Chur
//

import SwiftUI

struct RegionSettingsView: View {
    @Bindable var user: User

    var body: some View {
        List {
            Section {
                Picker("Region", selection: $user.country) {
                    ForEach(RegionDatabase.activeRegions) { region in
                        HStack {
                            Text(region.flag)
                            Text(region.name)
                        }
                        .tag(region.id)
                    }
                }
                .onChange(of: user.country) { _, newRegion in
                    TransferPartnerDatabase.loadFromBundle(region: newRegion)
                }

                HStack {
                    Text("Display Currency")
                    Spacer()
                    Text(CurrencyConversion.currencyCode(forCountry: user.country))
                        .foregroundStyle(Color.churMediumGray)
                }
            } footer: {
                Text("Your region determines which cards and reward rates are shown.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Region & Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}
