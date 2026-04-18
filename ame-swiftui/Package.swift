// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AMESwiftUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "AMESwiftUI", targets: ["AMESwiftUI"]),
        .executable(name: "ame-conformance-swift", targets: ["AMEConformanceCli"])
    ],
    dependencies: [],
    targets: [
        .target(name: "AMESwiftUI"),
        .executableTarget(name: "AMEConformanceCli", dependencies: ["AMESwiftUI"]),
        .testTarget(
            name: "AMESwiftUITests",
            dependencies: ["AMESwiftUI"]
        )
    ]
)
