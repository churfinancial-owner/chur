//
//  RestoreConflictSheet.swift
//  Chur
//

import SwiftUI

struct RestoreConflictSheet: View {
    let backup: ChurBackup
    let localCardCount: Int
    let onRestore: () -> Void
    let onKeepLocal: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var formattedBackupDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: backup.exportedAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)

                Text("Backup Found")
                    .font(.title2.bold())

                Text("Your Google account has a saved backup. Choose whether to restore it or keep the data currently on this device.")
                    .font(.subheadline)
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.bottom, 24)

            VStack(spacing: 0) {
                infoRow(
                    icon: "icloud.fill",
                    iconColor: .blue,
                    title: "Cloud Backup",
                    detail: cardCountLabel(backup.cards.count),
                    subtitle: "Saved \(formattedBackupDate)"
                )
                Divider().padding(.leading, 56)
                infoRow(
                    icon: "iphone",
                    iconColor: Color.churMediumGray,
                    title: "On This Device",
                    detail: cardCountLabel(localCardCount),
                    subtitle: nil
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            VStack(spacing: 10) {
                Button {
                    onRestore()
                    dismiss()
                } label: {
                    Text("Restore from Backup")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onKeepLocal()
                    dismiss()
                } label: {
                    Text("Keep Local Data")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func cardCountLabel(_ count: Int) -> String {
        count == 1 ? "1 card" : "\(count) cards"
    }

    private func infoRow(icon: String, iconColor: Color, title: String, detail: String, subtitle: String?) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.churMediumGray)
                }
            }

            Spacer()

            Text(detail)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
