import SwiftUI

/// The single architectural seam for the future Apple iPhone Duo dual-screen mode.
///
/// `evidence` is photo/condition content; `controls` is persistent listing/packing work.
/// Today's standard iPhone composes them on one screen. A future native fold API can
/// place the same two closures on separate displays by adding a `Mode` case here,
/// without changing callers or stored data. No fold is inferred from size classes,
/// mirroring, or screenshots; `current` stays `.singleScreen` until Apple ships a public API.
struct ListingWorkspaceLayout<Evidence: View, Controls: View>: View {
    enum Mode { case singleScreen }
    @Environment(\.dynamicTypeSize) private var textSize
    let mode: Mode
    let evidence: Evidence
    let controls: Controls

    init(mode: Mode = .singleScreen,
         @ViewBuilder evidence: () -> Evidence, @ViewBuilder controls: () -> Controls) {
        self.mode = mode; self.evidence = evidence(); self.controls = controls()
    }

    var body: some View {
        switch mode {
        case .singleScreen:
            // ponytail: side-by-side columns at standard text sizes, stacked for accessibility sizes.
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) { evidence; controls }
            } else {
                HStack(alignment: .top, spacing: 16) { evidence; controls }
            }
        }
    }
}
