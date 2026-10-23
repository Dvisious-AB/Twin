// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TwinCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TwinCore", targets: ["TwinCore"])
    ],
    targets: [
        .target(name: "TwinCore", path: "Sources/TwinCore"),
        .testTarget(name: "TwinCoreTests", dependencies: ["TwinCore"], path: "Tests/TwinCoreTests")
    ]
)
