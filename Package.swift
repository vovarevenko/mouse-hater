// swift-tools-version: 6.0
// Copyright © 2026 Vova Revenko
import PackageDescription

let package = Package(
    name: "MouseHater",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MouseHater",
            path: "Sources/MouseHater"
        )
    ],
    swiftLanguageModes: [.v5]
)
