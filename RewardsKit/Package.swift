// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RewardsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RewardsKit", targets: ["RewardsKit"]),
    ],
    targets: [
        .target(name: "RewardsKit"),
        .testTarget(name: "RewardsKitTests", dependencies: ["RewardsKit"]),
    ]
)
