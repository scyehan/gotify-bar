// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "GotifyBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GotifyBar",
            path: "Sources"
        ),
    ]
)
