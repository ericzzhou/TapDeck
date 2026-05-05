// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapDeck",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TapDeck",
            path: "Sources",
            exclude: ["AccelReader"]
        ),
        .executableTarget(
            name: "AccelReader",
            path: "Sources/AccelReader"
        ),
        .testTarget(
            name: "TapDeckTests",
            path: "Tests"
        ),
    ]
)
