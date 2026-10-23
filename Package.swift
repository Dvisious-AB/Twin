// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Twin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TwinCore", targets: ["TwinCore"]),
        .library(name: "TwinPro", targets: ["TwinPro"])
    ],
    targets: [
        .target(name: "TwinCore", path: "Sources/TwinCore"),
        .target(name: "TwinPro", path: "Sources/TwinPro"),
        .testTarget(name: "TwinCoreTests", dependencies: ["TwinCore"], path: "Tests/TwinCoreTests")
    ]
)
