// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Winamp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Winamp",
            path: "Sources/Winamp"
        )
    ]
)
