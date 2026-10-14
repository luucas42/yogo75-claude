// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Yogo",
    platforms: [.macOS("15.0")],
    targets: [
        .target(name: "YogoCore"),
        .executableTarget(name: "yogo", dependencies: ["YogoCore"]),
        .executableTarget(name: "YogoApp", dependencies: ["YogoCore"]),
        .testTarget(name: "YogoCoreTests", dependencies: ["YogoCore"]),
    ]
)
