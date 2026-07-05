// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Twig",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TwigCore"),
        .executableTarget(
            name: "Twig",
            dependencies: ["TwigCore"]
        ),
        .testTarget(
            name: "TwigCoreTests",
            dependencies: ["TwigCore"]
        ),
    ]
)
