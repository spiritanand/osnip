// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "osnip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "osnip", targets: ["osnip"]),
    ],
    targets: [
        .target(name: "OsnipCore"),
        .executableTarget(name: "osnip", dependencies: ["OsnipCore"]),
        .testTarget(name: "OsnipCoreTests", dependencies: ["OsnipCore"]),
    ]
)
