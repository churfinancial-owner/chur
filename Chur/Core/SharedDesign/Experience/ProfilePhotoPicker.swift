//
//  ProfilePhotoPicker.swift
//  Chur
//
//  Shared component for picking and displaying a user profile photo.
//  Uses UIImagePickerController with allowsEditing = true for native
//  "Move and Scale" crop UI. Used in onboarding and Settings.
//
//  When initialised with a profileEmoji binding, also renders an emoji
//  fallback, an emoji-selection row, and a "Remove Photo" button.
//

import SwiftUI

struct ProfilePhotoPicker: View {
    @Binding var profilePhotoData: Data?
    @Binding var profileEmoji: String
    var diameter: CGFloat = 120
    var showCameraOverlay: Bool = true
    var allowsEmojiPicker: Bool = false

    @State private var showPicker = false

    // MARK: - Inits

    /// Original init — no emoji support. Existing call sites unchanged.
    init(profilePhotoData: Binding<Data?>, diameter: CGFloat = 120, showCameraOverlay: Bool = true) {
        self._profilePhotoData = profilePhotoData
        self._profileEmoji = .constant("😊")
        self.diameter = diameter
        self.showCameraOverlay = showCameraOverlay
        self.allowsEmojiPicker = false
    }

    /// Extended init — enables emoji fallback, emoji picker row, and remove-photo button.
    init(profilePhotoData: Binding<Data?>, profileEmoji: Binding<String>, diameter: CGFloat = 120, showCameraOverlay: Bool = true) {
        self._profilePhotoData = profilePhotoData
        self._profileEmoji = profileEmoji
        self.diameter = diameter
        self.showCameraOverlay = showCameraOverlay
        self.allowsEmojiPicker = true
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Avatar — tapping always opens the photo picker
            Button {
                showPicker = true
            } label: {
                profilePhotoView
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPicker) {
                ImageCropPicker(imageData: $profilePhotoData)
                    .ignoresSafeArea()
            }

            if allowsEmojiPicker {
                // Hint
                Text(profilePhotoData != nil ? "Tap photo to change" : "Tap circle to add a photo")
                    .font(.churMicro())
                    .foregroundStyle(Color.churMediumGray)

                // Emoji row
                emojiPickerRow

                // Remove photo (only when a photo is set)
                if profilePhotoData != nil {
                    Button("Remove Photo", role: .destructive) {
                        profilePhotoData = nil
                    }
                    .font(.churFootnote())
                }
            }
        }
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var profilePhotoView: some View {
        ZStack {
            if let data = profilePhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
            } else if allowsEmojiPicker {
                Circle()
                    .fill(Color.churOlive.opacity(0.12))
                    .frame(width: diameter, height: diameter)
                    .overlay {
                        Text(profileEmoji.isEmpty ? "😊" : profileEmoji)
                            .font(.system(size: diameter * 0.48))
                    }
            } else {
                Circle()
                    .fill(Color.churOlive.opacity(0.15))
                    .frame(width: diameter, height: diameter)
                    .overlay {
                        if showCameraOverlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: diameter * 0.27))
                                .foregroundStyle(Color.churOlive)
                        }
                    }
            }

            // Edit badge when photo exists
            if profilePhotoData != nil && showCameraOverlay {
                Circle()
                    .fill(Color.churOlive)
                    .frame(width: diameter * 0.3, height: diameter * 0.3)
                    .overlay {
                        Image(systemName: "pencil")
                            .font(.system(size: diameter * 0.14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: diameter * 0.35, y: diameter * 0.35)
            }
        }
    }

    // MARK: - Emoji Picker Row

    private static let defaultEmojis = ["😊", "😎", "🤩", "🥳", "🤑", "💳", "✈️", "🏆", "🎯", "🌟"]

    private var emojiPickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.defaultEmojis, id: \.self) { emoji in
                    let isSelected = profileEmoji == emoji && profilePhotoData == nil
                    Button {
                        profilePhotoData = nil
                        profileEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(width: 48, height: 48)
                            .background(isSelected ? Color.churOlive.opacity(0.12) : Color.clear)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.churOlive : Color.churLightGray,
                                            lineWidth: isSelected ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Image Processing

    /// Compresses image to JPEG (max 400px, 70% quality)
    static func compress(_ image: UIImage, quality: CGFloat = 0.7, maxDimension: CGFloat = 400) -> Data {
        let size = image.size
        if max(size.width, size.height) > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return resized.jpegData(compressionQuality: quality) ?? Data()
        }
        return image.jpegData(compressionQuality: quality) ?? Data()
    }
}

// MARK: - UIImagePickerController wrapper

/// Presents the photo library with allowsEditing = true, giving the user
/// the native "Move and Scale" square-crop interface before confirming.
private struct ImageCropPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCropPicker
        init(_ parent: ImageCropPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            if let image {
                parent.imageData = ProfilePhotoPicker.compress(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
