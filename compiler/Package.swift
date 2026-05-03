// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "compiler",
    products: [
        .library(name: "WeftCompiler", targets: ["WeftCompiler"]),
    ],
    dependencies: [
        .package(path: "../ir"),
        // .package(path: "../runtime"),  // temporarily disabled
    ],
    targets: [
        .target(
            name: "WeftCompiler",
            dependencies: [.product(name: "WeftIR", package: "ir")],
            path: "Sources"
        ),
        .executableTarget(
            name: "compiler",
            dependencies: [
                "WeftCompiler",
                // .product(name: "WeftRuntime", package: "runtime"),  // temporarily disabled
            ],
            path: "CLI"
        ),
    ]
)
