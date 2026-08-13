// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "RecallKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RecallKit", targets: ["RecallKit"]),
    ],
    targets: [
        .target(name: "RecallKit"),
        .testTarget(
            name: "RecallKitTests",
            dependencies: ["RecallKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
