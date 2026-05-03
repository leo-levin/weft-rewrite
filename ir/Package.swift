// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "weft-ir",
  products: [
    .library(name: "WeftIR", targets: ["WeftIR"])
  ],
  targets: [
    .target(name: "WeftIR", path: "Sources")
  ]
)
