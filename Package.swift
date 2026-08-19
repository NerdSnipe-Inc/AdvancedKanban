// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AdvancedKanban",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AdvancedKanban", targets: ["AdvancedKanban"]),
        .library(name: "AdvancedKanbanSwiftData", targets: ["AdvancedKanbanSwiftData"]),
    ],
    targets: [
        .target(name: "AdvancedKanban"),
        .target(
            name: "AdvancedKanbanSwiftData",
            dependencies: ["AdvancedKanban"]
        ),
        .testTarget(
            name: "AdvancedKanbanTests",
            dependencies: ["AdvancedKanban", "AdvancedKanbanSwiftData"]
        ),
    ]
)
