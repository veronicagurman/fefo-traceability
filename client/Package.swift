// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FEFOTraceability",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "FEFOTraceability", targets: ["FEFOTraceability"])
    ],
    targets: [
        .executableTarget(name: "FEFOTraceability")
    ]
)
