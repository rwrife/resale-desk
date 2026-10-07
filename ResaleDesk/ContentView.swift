import SwiftUI
import ResaleDeskKit
import ResaleDeskStore

/// M1 bootstrap screen. Inventory and condition capture arrive in issue #3.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("Resale Desk")
                .font(.title)
                .accessibilityAddTraits(.isHeader)
            Text("Your offline resale workspace")
            Text("Inventory and condition capture are coming next.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
