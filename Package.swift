// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirText",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "AirText", targets: ["AirText"])],
    targets: [
        .target(name: "AirTextCore"),
        .executableTarget(name: "AirText", dependencies: ["AirTextCore"]),
        .testTarget(name: "AirTextCoreTests", dependencies: ["AirTextCore"])
    ]
)
