// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iadente",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "iadente", targets: ["iadente"]),
        .executable(name: "iadente-reader", targets: ["IadenteReader"]),
        .executable(name: "iadente-control", targets: ["IadenteControl"]),
    ],
    dependencies: [
        .package(path: "Vendor/Defaults"),
        .package(path: "Vendor/SMCKit"),
    ],
    targets: [
        .target(
            name: "IadenteShared",
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
            name: "IadenteReader",
            dependencies: [
                "IadenteShared",
                "smc_power",
            ],
            path: "Helper",
            exclude: [
                "HelperProtocol.swift",
                "Info.plist",
            ]
        ),
        .executableTarget(
            name: "IadenteControl",
            dependencies: [
                "IadenteShared",
                "smc_power",
            ],
            path: "ChargingHelper",
            exclude: [
                "ChargingHelperProtocol.swift",
                "com.iadente.app.control.plist",
            ]
        ),
        .executableTarget(
            name: "iadente",
            dependencies: [
                "IadenteShared",
                "smc_power",
                .product(name: "Defaults", package: "Defaults"),
            ],
            path: "Stasis",
            exclude: [
                "Assets.xcassets",
                "L10n",
            ]
        ),
    ]
)
