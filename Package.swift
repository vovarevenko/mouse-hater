// swift-tools-version: 6.0
// Copyright © 2026 Vova Revenko
import PackageDescription

let package = Package(
    name: "MouseHater",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MouseHaterCore",
            path: "Sources/MouseHaterCore"
        ),
        .executableTarget(
            name: "MouseHater",
            dependencies: ["MouseHaterCore"],
            path: "Sources/MouseHater"
        )
    ],
    swiftLanguageModes: [.v5]
)
