// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Beam",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BeamCore"),
        .executableTarget(name: "Beam", dependencies: ["BeamCore"]),
        .testTarget(name: "BeamCoreTests", dependencies: ["BeamCore"]),
    ]
)
