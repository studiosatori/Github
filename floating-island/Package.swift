// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FloatingIsland",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "FloatingIsland", path: "Sources/FloatingIsland")
    ]
)
