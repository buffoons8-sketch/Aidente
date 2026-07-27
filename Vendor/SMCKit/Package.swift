// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SMCKit",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "SMC", targets: ["SMC"]),
        .library(name: "SMCKit", targets: ["SMCKit"]),
    ],
    targets: [
        .target(
            name: "SMC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SMCKit",
            dependencies: ["SMC"]
        ),
    ]
)
