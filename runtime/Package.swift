// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "weft-runtime",
    products: [
        .library(name: "WeftRuntime", targets: ["WeftRuntime"]),
    ],
    dependencies: [
        .package(path: "../ir"),
    ],
    targets: [
        .target(
            name: "WeftRuntime",
            dependencies: [.product(name: "WeftIR", package: "ir")],
            path: "sources"
        ),
    ]
)
