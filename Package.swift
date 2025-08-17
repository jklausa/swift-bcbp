// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-bcbp",
    products: [
        .library(
            name: "swift-bcbp",
            targets: ["swift-bcbp"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-parsing", .upToNextMajor(from: "0.14.1")),
    ],
    targets: [
        .target(
            name: "swift-bcbp",
            dependencies: [.product(name: "Parsing", package: "swift-parsing")],
        ),
        .testTarget(
            name: "swift-bcbp-tests",
            dependencies: ["swift-bcbp"]
        ),
    ]
)
