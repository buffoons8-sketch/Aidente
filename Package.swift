// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Aidente",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Aidente", targets: ["Aidente"]),
        .executable(name: "AidenteReader", targets: ["AidenteReader"]),
        .executable(name: "AidenteControl", targets: ["AidenteControl"]),
    ],
    dependencies: [
        .package(path: "Vendor/Defaults"),
        .package(path: "Vendor/SMCKit"),
    ],
    targets: [
        .target(
            name: "AidenteShared",
            path: "Shared"
        ),
        .target(
            name: "smc_power",
            dependencies: [
                .product(name: "SMCKit", package: "SMCKit")
            ],
            path: "SMCPower"
        ),
        .executableTarget(
            name: "AidenteReader",
            dependencies: [
                "AidenteShared",
                "smc_power",
            ],
            path: "Helper",
            exclude: [
                "HelperProtocol.swift",
                "Info.plist",
            ]
        ),
        .executableTarget(
            name: "AidenteControl",
            dependencies: [
                "AidenteShared",
                "smc_power",
            ],
            path: "ChargingHelper",
            exclude: [
                "ChargingHelperProtocol.swift",
                "com.aidente.app.control.plist",
            ]
        ),
        .executableTarget(
            name: "Aidente",
            dependencies: [
                "AidenteShared",
                "smc_power",
                .product(name: "Defaults", package: "Defaults"),
            ],
            path: "Aidente",
            exclude: [
                "Assets.xcassets",
                "L10n",
            ]
        ),
    ]
)
