// swift-tools-version:6.0
import PackageDescription

// Pure-Swift resale domain package. No UI or Apple-only frameworks.
// Rubric and ledger behavior arrive in M2; Linux-testable by design.
let package = Package(
    name: "ResaleDeskKit",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "ResaleDeskKit", targets: ["ResaleDeskKit"]),
    ],
    targets: [
        .target(name: "ResaleDeskKit"),
        .testTarget(name: "ResaleDeskKitTests", dependencies: ["ResaleDeskKit"]),
    ]
)
