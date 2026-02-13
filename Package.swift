// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CardDeckInteractions",
    platforms: [.iOS(.v18)],
    targets: [
        .executableTarget(
            name: "CardDeckApp",
            path: "Sources/CardDeckApp"
        ),
    ]
)
