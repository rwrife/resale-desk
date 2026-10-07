// swift-tools-version:6.0
import PackageDescription

// ResaleDeskStore — persistence layer for ResaleDesk (GRDB/SQLite stub in M1).
// Pure domain storage package, Linux-testable by design.
let package = Package(
    name: "ResaleDeskStore",
    platforms: [
        .iOS("26.0"),
    ],
    products: [
        .library(name: "ResaleDeskStore", targets: ["ResaleDeskStore"]),
    ],
    dependencies: [
        .package(path: "../ResaleDeskKit"),
    ],
    targets: [
        .target(name: "ResaleDeskStore", dependencies: ["ResaleDeskKit"]),
        .testTarget(name: "ResaleDeskStoreTests", dependencies: ["ResaleDeskStore"]),
    ]
)
