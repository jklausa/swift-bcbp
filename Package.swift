// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "swift-bcbp",
    platforms: [
        .iOS(.v13),
        .macOS(.v12),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "SwiftBCBP",
            targets: ["SwiftBCBP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-parsing", .upToNextMajor(from: "0.14.1")),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.54.0"),
        .package(url: "https://github.com/realm/SwiftLint", from: "0.57.0"),
    ],
    targets: [
        .target(
            name: "SwiftBCBP",
            dependencies: [.product(name: "Parsing", package: "swift-parsing")]
        ),
        .testTarget(
            name: "SwiftBCBPTests",
            dependencies: ["SwiftBCBP"],
            resources: [
                .copy("Examples")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")
            ]
        ),
    ]
)
