// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "compiler",
    targets: [
        .executableTarget(
            name: "compiler",
            path: "Sources"
        )
    ]
)
