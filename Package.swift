// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Catification",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Catification",
            path: "Sources/Catification"
        ),
        .testTarget(
            name: "CatificationTests",
            dependencies: ["Catification"],
            path: "Tests/CatificationTests"
        ),
    ]
)
