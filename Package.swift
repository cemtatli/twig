// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorktreeGUI",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WorktreeCore"),
        .executableTarget(
            name: "WorktreeGUI",
            dependencies: ["WorktreeCore"]
        ),
        .testTarget(
            name: "WorktreeCoreTests",
            dependencies: ["WorktreeCore"]
        ),
    ]
)
