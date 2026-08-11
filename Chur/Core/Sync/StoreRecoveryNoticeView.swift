//
//  StoreRecoveryNoticeView.swift
//  Chur
//
//  Shown once when `ChurStoreRecovery` had to reset the local store.
//
//  Lives beside the recovery machinery rather than in Features/ because it is
//  only meaningful together with `ChurStoreRecovery` — it exists to explain
//  that one event and nothing else.
//
//  Without it, a user whose store was reset is dropped into first-run
//  onboarding with no explanation: their wallet looks deleted, and the one
//  action that gets it back (sign in with Google) looks like an optional
//  account-creation step they can skip. This says what happened and points at
//  that action.
//

import SwiftUI

struct StoreRecoveryNoticeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.clockwise.icloud")
                .font(.churBigTitle1())
                .foregroundStyle(Color.churWarning)
                .padding(.top, 48)

            VStack(spacing: 12) {
                Text("We had to reset your data")
                    .font(.churTitle2())
                    .foregroundStyle(Color.churOlivetext)
                    .multilineTextAlignment(.center)

                Text("Chur couldn't open your saved wallet on this device, so it started a fresh one. Nothing was deleted from your backup.")
                    .font(.churBody())
                    .foregroundStyle(Color.churDarkGray)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Sign in with Google to restore your cards, notes and benefit history.",
                      systemImage: "arrow.down.circle")
                Label("Not backed up? You'll need to add your cards again.",
                      systemImage: "info.circle")
            }
            .font(.churFootnote())
            .foregroundStyle(Color.churDarkGray)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.churLightGray.opacity(0.25))
            )

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.churHeadline())
                    .foregroundStyle(Color.churOffWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.churOlive)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.churOffWhite.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}
