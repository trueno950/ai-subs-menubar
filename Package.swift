// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AISubs",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AISubsCore"),
        .executableTarget(
            name: "AISubs",
            dependencies: ["AISubsCore"]
        ),
        .executableTarget(
            name: "AISubsLogicTests",
            dependencies: ["AISubsCore"]
        )
    ]
)
