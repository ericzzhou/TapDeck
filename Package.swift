// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapDeck",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TapDeck",
            path: "Sources"
        ),
    ]
)
