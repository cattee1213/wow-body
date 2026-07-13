// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "macos_hand_server",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "macos_hand_server",
            path: "Sources"
        ),
    ]
)
