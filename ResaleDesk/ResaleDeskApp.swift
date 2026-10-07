import SwiftUI
import ResaleDeskKit
import ResaleDeskStore

/// ResaleDesk app entry point.
///
/// iPhone-only by product contract (`TARGETED_DEVICE_FAMILY = 1` in every
/// build configuration; CI enforces it pre- and post-build). Zero-network by
/// construction: no network APIs anywhere in app or package sources — CI
/// enforces an empty-allowlist scan per `toolchain.json`.
@main
struct ResaleDeskApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
