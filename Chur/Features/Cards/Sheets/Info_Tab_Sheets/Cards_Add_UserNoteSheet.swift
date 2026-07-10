import SwiftUI
import SwiftData

private enum NotePreset: String, CaseIterable {
    case darkOnLight = "Light Theme"
    case lightOnDark = "Dark Theme"

    var textHex: String {
        switch self {
        case .lightOnDark: return "#FFFFFF"
        case .darkOnLight: return "#000000"
        }
    }
    var bgHex: String {
        switch self {
        case .lightOnDark: return "#777544"
        case .darkOnLight: return "#EBE5C8"
        }
    }
    var textColor: Color {
        switch self {
        case .lightOnDark: return .white
        case .darkOnLight: return .black
        }
    }
    var bgColor: Color {
        switch self {
        case .lightOnDark: return .churDarkOlive
        case .darkOnLight: return .churOliveLight
        }
    }
}

struct CardsUserNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard

    @State private var noteText: String
    @State private var preset: NotePreset
    @State private var isNoteVisible: Bool
    
    private let characterLimit = 250 // Set your desired limit here

    init(card: CreditCard) {
        self.card = card
        _noteText = State(initialValue: card.note)
        _isNoteVisible = State(initialValue: card.noteIsVisible)
        _preset = State(initialValue: NotePreset.allCases.first { $0.textHex == card.noteTextColor } ?? .lightOnDark)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    // MARK: - Note Input Section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("NOTE")
                                .font(.churSmallBold())
                                .foregroundStyle(Color.churOlive)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            // Character Count
                            Text("\(noteText.count)/\(characterLimit)")
                                .font(.churSmall())
                                .foregroundStyle(noteText.count >= characterLimit ? Color.churError : Color.churMediumGray)
                        }
                        .padding(.horizontal, 4)

                        VStack(alignment: .trailing, spacing: 12) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $noteText)
                                    .frame(height: 110) // Fixed height
                                    .font(.churRowTextMedium())
                                    .scrollContentBackground(.hidden)
                                    .padding(12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .onChange(of: noteText) { _, newValue in
                                        if newValue.count > characterLimit {
                                            noteText = String(newValue.prefix(characterLimit))
                                        }
                                    }
                                
                                if noteText.isEmpty {
                                    Text("What's this card for?")
                                        .font(.churRowTextMedium())
                                        .foregroundStyle(Color.churLightGray)
                                        .padding(.top, 20)
                                        .padding(.leading, 18)
                                        .allowsHitTesting(false)
                                }
                            }

                            if !card.note.isEmpty {
                                Button {
                                    noteText = ""
                                    saveChanges()
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    dismiss()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("Clear")
                                    }
                                    .font(.churSmallBold())
                                    .foregroundStyle(Color.churError)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 4)
                            }
                        }
                    }

                    // MARK: - Appearance & Visibility Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("APPEARANCE")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churOlive)
                            .tracking(0.5)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            // Visibility Toggle
                            HStack {
                                Image(systemName: isNoteVisible ? "eye" : "eye.slash")
                                    .font(.churRowText())
                                    .foregroundStyle(Color.churDarkOlive)
                                    .frame(width: 22)
                                
                                Text("Show on Card")
                                    .font(.churRowText())
                                    .foregroundStyle(Color.churDarkGray)
                                
                                Spacer()
                                
                                Toggle("", isOn: $isNoteVisible)
                                    .labelsHidden()
                                    .tint(Color.churOlive)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Divider().padding(.horizontal, 16).opacity(0.5)

                            // Theme Presets (Grays out when isNoteVisible is false)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("THEME")
                                    .font(.churSmallBold())
                                    .foregroundStyle(Color.churMediumGray.opacity(0.8))
                                
                                HStack(spacing: 10) {
                                    ForEach(NotePreset.allCases, id: \.self) { p in
                                        swatchButton(p)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .opacity(isNoteVisible ? 1.0 : 0.4) // Gray out effect
                            .disabled(!isNoteVisible)           // Disable interaction
                            .animation(.snappy, value: isNoteVisible)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Card Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                        .font(.churRowText())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("📝").font(.churBigTitle1())
            Text("Add a note to appear on your card.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func swatchButton(_ p: NotePreset) -> some View {
        let isSelected = preset == p
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { preset = p }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "note.text")
                    .font(.churMicroBold())
                Text(p.rawValue)
                    .font(.churFootnoteBold())
            }
            .foregroundStyle(p.textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(p.bgColor.opacity(0.55))
                }
            }
            .clipShape(Capsule())
            .overlay {
                if isSelected {
                    Capsule().stroke(Color.churOlive, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func saveChanges() {
        card.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        card.noteTextColor = preset.textHex
        card.noteBgColor = preset.bgHex
        card.noteIsVisible = isNoteVisible
    }
}
