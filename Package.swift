// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-bcbp",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
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
    ],
    targets: [
        .target(
            name: "SwiftBCBP",
            dependencies: [.product(name: "Parsing", package: "swift-parsing")],
        ),
        .testTarget(
            name: "SwiftBCBPTests",
            dependencies: ["SwiftBCBP"],
            resources: [
                .copy("Examples")
            ]
        ),
    ]
)
