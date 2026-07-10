//
//  MemberInfoSection.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI
import SwiftData

// MARK: - Member Info Section
struct MemberInfoSection: View {
    let user: User
    var onAvatarTap: (() -> Void)? = nil
    
    /// Which slot index (0-3) is being edited; nil = picker closed
    @State private var editingSlotIndex: Int? = nil
    
    // Fixed offsets for the 4 corners
    private let cornerOffsets: [(x: CGFloat, y: CGFloat, rotation: Double)] = [
        (x: -52, y: -72, rotation: -12), // Slot 0: Top-Left
        (x:  58, y: -68, rotation:   7), // Slot 1: Top-Right
        (x: -50, y:  70, rotation:  10), // Slot 2: Bottom-Left
        (x:  68, y:  66, rotation:  -5), // Slot 3: Bottom-Right
    ]
    
    /// Maps the user's string array to the FinancialStrategy enum, preserving empty slots
    private var slots: [FinancialStrategy?] {
        (0..<4).map { index in
            guard index < user.strategyPreferences.count else { return nil }
            let rawValue = user.strategyPreferences[index]
            return rawValue.isEmpty ? nil : FinancialStrategy(rawValue: rawValue)
        }
    }
    
    /// Gradient colors for avatar, ignoring empty string placeholders
    private var avatarGradientColors: [Color] {
        let activeColors = user.strategyPreferences
            .compactMap { rawValue -> Color? in
                guard !rawValue.isEmpty else { return nil }
                return FinancialStrategy(rawValue: rawValue)?.color
            }
        
        if activeColors.isEmpty {
            return [Color.churGold.opacity(0.4), Color.churGold.opacity(0.25)]
        }
        return activeColors.map { $0.opacity(0.45) }
    }
    
    var body: some View {
        ZStack {
            // Layer 1: The 4 polaroid slots in fixed positions
            ForEach(0..<4, id: \.self) { index in
                let corner = cornerOffsets[index]
                let strategy = slots[index]
                
                PolaroidSlot(strategy: strategy) {
                    editingSlotIndex = index
                }
                .offset(x: corner.x, y: corner.y)
                .rotationEffect(.degrees(corner.rotation))
                .zIndex(Double(index))
            }
            
            // Layer 2: Central user avatar
            Button {
                onAvatarTap?()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: avatarGradientColors + [avatarGradientColors.first ?? Color.churGold.opacity(0.4)],
                                center: .center
                            )
                        )
                        .frame(width: 130, height: 130)
                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                        .animation(.easeInOut(duration: 0.5), value: user.strategyPreferences)
                    
                    if let data = user.profilePhotoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        Text(user.profileEmoji)
                            .font(.system(size: 68))
                    }
                }
            }
            .buttonStyle(.plain)
            .zIndex(10)
        }
        .frame(width: 320, height: 290)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .sheet(item: Binding(
            get: { editingSlotIndex.map { SlotID(index: $0) } },
            set: { editingSlotIndex = $0?.index }
        )) { slotID in
            SlotPickerSheet(
                user: user,
                slotIndex: slotID.index,
                currentStrategy: slots[slotID.index]
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct SlotID: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Polaroid Slot

private struct PolaroidSlot: View {
    let strategy: FinancialStrategy?
    let onTap: () -> Void
    
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 115
    
    var body: some View {
        Button(action: onTap) {
            if let strategy {
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(strategy.color.opacity(0.15))
                            .frame(width: cardWidth - 14, height: cardHeight - 36)
                        
                        Text(strategy.emoji)
                            .font(.system(size: 42))
                    }
                    .padding(.top, 7)
                    .padding(.horizontal, 7)
                    
                    Text(strategy.displayName)
                        .font(.churNanoBold())
                        .foregroundStyle(Color.churDarkGray)
                        .lineLimit(1)
                        .padding(.top, 5)
                        .padding(.bottom, 7)
                }
                .frame(width: cardWidth, height: cardHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 3)
                )
            } else {
                // Empty state stays in place
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            Color.churSilver.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                    
                    Image(systemName: "plus")
                        .font(.churBigTitle4())
                        .foregroundStyle(Color.churSilver.opacity(0.5))
                }
                .frame(width: cardWidth, height: cardHeight)
                .background(Color.white.opacity(0.001)) // Helps tap target
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slot Picker Sheet (1 Column, Large UI)

private struct SlotPickerSheet: View {
    let user: User
    let slotIndex: Int
    let currentStrategy: FinancialStrategy?
    
    @Environment(\.dismiss) private var dismiss
    
    private var usedInOtherSlots: Set<String> {
        // Find strategies used in slots OTHER than the current one
        var used = Set<String>()
        for (idx, pref) in user.strategyPreferences.enumerated() {
            if idx != slotIndex && !pref.isEmpty {
                used.insert(pref)
            }
        }
        return used
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("CHOOSE A CARD STRATEGY")
                        .font(.churSubheadline())
                        .foregroundStyle(Color.churOlive)
                        .tracking(0.5)
                    
                    Text(currentStrategy != nil ? "Tap to swap, or remove" : "Pick one for this corner")
                        .font(.churCaptionMedium())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                
                if currentStrategy != nil {
                    Button {
                        clearSlot()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Remove Strategy")
                        }
                        .font(.churFootnoteBold())
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.red.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                
                // Single Column Grid
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                    ForEach(FinancialStrategy.allCases) { strategy in
                        let isCurrent = strategy == currentStrategy
                        let isUsedElsewhere = usedInOtherSlots.contains(strategy.rawValue)
                        
                        Button {
                            assignStrategy(strategy)
                            dismiss()
                        } label: {
                            HStack(spacing: 16) {
                                Text(strategy.emoji)
                                    .font(.churBigTitle3())
                                    .frame(width: 50, height: 50)
                                    .background(strategy.color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(strategy.displayName)
                                        .font(.churHeadline())
                                        .foregroundStyle(isUsedElsewhere ? .secondary : .primary)
                                    
                                    Text(strategy.tagline)
                                        .font(.churFootnoteMedium())
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if isCurrent {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.churBigTitle4())
                                        .foregroundStyle(strategy.color)
                                } else if isUsedElsewhere {
                                    Text("In Use")
                                        .font(.churBadgeBold())
                                        .foregroundStyle(.secondary.opacity(0.5))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().stroke(.secondary.opacity(0.3), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isCurrent ? strategy.color.opacity(0.08) : Color.primary.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isCurrent ? strategy.color.opacity(0.3) : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUsedElsewhere)
                        .opacity(isUsedElsewhere ? 0.5 : 1.0)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - Actions
    
    private func assignStrategy(_ strategy: FinancialStrategy) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // Fill array with placeholders until we reach the tapped index
            while user.strategyPreferences.count <= slotIndex {
                user.strategyPreferences.append("")
            }
            // Assign to the specific index
            user.strategyPreferences[slotIndex] = strategy.rawValue
        }
    }
    
    private func clearSlot() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            // Set to empty string instead of removing to keep indices stable
            if slotIndex < user.strategyPreferences.count {
                user.strategyPreferences[slotIndex] = ""
            }
        }
    }
}
