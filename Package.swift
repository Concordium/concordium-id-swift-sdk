// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "concordium-id-swift-sdk",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "concordium-id-swift-sdk", targets: ["concordium-id-swift-sdk"])
    ],
    dependencies: [
        .package(url: "https://github.com/Electric-Coin-Company/MnemonicSwift.git", from: "2.2.4"),
        .package(url: "https://github.com/Concordium/concordium-swift-sdk.git", from: "1.0.2"),
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.54.0")
    ],
    targets: [
        .target(
            name: "concordium-id-swift-sdk",
            dependencies: [
                .product(name: "Concordium", package: "concordium-swift-sdk"),
                "MnemonicSwift"
            ],
            path: "Sources",
            resources: [
                .process("Assets")
            ]
        )
    ]
)


