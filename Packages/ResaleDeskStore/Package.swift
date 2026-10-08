// swift-tools-version:6.0
import PackageDescription

// ResaleDeskStore — persistence layer for ResaleDesk (GRDB/SQLite).
// Pure domain storage package, Linux-testable by design.
let package = Package(
    name: "ResaleDeskStore",
    platforms: [
        .iOS("26.0"),
        .macOS("15.0"), // Host-side package tests only, not a macOS app.
    ],
    products: [
        .library(name: "ResaleDeskStore", targets: ["ResaleDeskStore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
        .package(path: "../ResaleDeskKit"),
    ],
    targets: [
        .target(
            name: "ResaleDeskStore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                "ResaleDeskKit",
            ]
        ),
        .testTarget(
            name: "ResaleDeskStoreTests",
            dependencies: ["ResaleDeskStore"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
