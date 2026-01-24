//
//  ProfilePhotoPicker.swift
//  Chur
//
//  Shared component for picking and displaying a user profile photo.
//  Uses UIImagePickerController with allowsEditing = true for native
//  "Move and Scale" crop UI. Used in onboarding and Settings.
//

import SwiftUI

struct ProfilePhotoPicker: View {
    @Binding var profilePhotoData: Data?
    var diameter: CGFloat = 120
    var showCameraOverlay: Bool = true

    @State private var showPicker = false

    var body: some View {
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
    }

    @ViewBuilder
    private var profilePhotoView: some View {
        ZStack {
            if let data = profilePhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
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
            // Prefer the edited (cropped) image over the original
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
