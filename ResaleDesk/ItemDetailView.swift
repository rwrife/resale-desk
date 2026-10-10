import SwiftUI
import UIKit
import ResaleDeskKit

struct ItemDetailView: View {
    let model: InventoryModel
    let itemID: String
    @State private var editing = false
    @State private var capturing = false
    @State private var error: String?
    @State private var removing: String?

    private var item: Item? { model.items.first { $0.id == itemID } }

    var body: some View {
        if let item {
            List {
                Section("Item") {
                    Text(item.title).font(.headline)
                    Text(item.category ?? "Uncategorized")
                    Button("Edit item") { editing = true }
                        .frame(minHeight: 48).accessibilityIdentifier("item.edit")
                    NavigationLink("Evaluate condition") { ConditionView(model: model, item: item) }
                        .frame(minHeight: 48).accessibilityIdentifier("condition.open")
                }
                Section("Local condition photos") {
                    Button("Capture defect photo", systemImage: "camera") {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            capturing = true
                        } else {
                            error = "Camera unavailable on this device. Item and condition capture still work."
                        }
                    }
                    .frame(minHeight: 48)
                    .accessibilityIdentifier("photo.capture")
                    Text("Camera capture only. Photos stay in this app, with no library or cloud access. Maximum 20 MB per saved photo.")
                        .font(.footnote)
                    ForEach(Array(item.photoPaths.enumerated()), id: \.element) { index, path in
                        VStack(alignment: .leading, spacing: 12) {
                            if let image = UIImage(data: (try? model.photoBytes(path, item: item)) ?? Data()) {
                                Image(uiImage: image).resizable().scaledToFit()
                                    .accessibilityLabel("Condition evidence photo \(index + 1) for \(item.title)")
                                    .accessibilityIdentifier("photo.image.\(index)")
                            } else { Text("Photo file unavailable. The manifest entry is retained.") }
                            Button("Remove photo \(index + 1)", role: .destructive) { removing = path }
                                .frame(minHeight: 48).accessibilityIdentifier("photo.remove.\(index)")
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("photo.error") } }
            }
            .navigationTitle("Item workspace")
            .sheet(isPresented: $editing) { ItemEditor(model: model, item: item) }
            .fullScreenCover(isPresented: $capturing) {
                CameraCapture { image in
                    capturing = false
                    guard let image else { return }
                    do {
                        guard let jpeg = image.jpegData(compressionQuality: 0.85),
                              let current = self.item else { throw CocoaError(.fileReadCorruptFile) }
                        // Encode image pixels only, not camera metadata or location.
                        try model.attach(jpeg, to: current)
                    } catch { self.error = "Photo capture failed: \(error.localizedDescription)" }
                }.ignoresSafeArea()
            }
            .confirmationDialog("Remove this local evidence photo?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
                Button("Remove photo", role: .destructive) {
                    guard let path = removing else { return }
                    do { try model.detach(path, from: item) }
                    catch { self.error = error.localizedDescription }
                    removing = nil
                }
            }
        } else { Text("Item unavailable") }
    }
}

// ponytail: camera-only capture preserves strict offline acquisition; library imports
// need explicit local-resource checks before they can be added.
struct CameraCapture: UIViewControllerRepresentable {
    let onCapture: @MainActor (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: @MainActor (UIImage?) -> Void
        init(onCapture: @escaping @MainActor (UIImage?) -> Void) { self.onCapture = onCapture }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }
    }
}
