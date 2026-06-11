// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IRefresh",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IRefresh", targets: ["IRefresh"]),
    ],
    targets: [
        .target(name: "IRefresh"),
        .testTarget(name: "IRefreshTests", dependencies: ["IRefresh"]),
    ]
)
