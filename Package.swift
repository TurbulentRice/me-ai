// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PersonalLLM",
    defaultLocalization: "en",
    platforms: [
        .iOS("18.0"),  // Required for SwiftLlama
        .macOS("15.0")  // Required for SwiftLlama
    ],
    products: [
        .library(
            name: "PersonalLLMCore",
            targets: ["PersonalLLMCore"]
        ),
    ],
    dependencies: [
        // SQLite database
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        // Async utilities
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        // llama.cpp Swift wrapper
        .package(url: "https://github.com/ShenghaiWang/SwiftLlama.git", from: "0.4.0"),
    ],
    targets: [
        // Core library with all business logic
        .target(
            name: "PersonalLLMCore",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "SwiftLlama", package: "SwiftLlama"),
            ],
            path: "Sources/PersonalLLMCore",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("CryptoKit", .when(platforms: [.iOS, .macOS]))
            ]
        ),

        // Unit tests
        .testTarget(
            name: "PersonalLLMCoreTests",
            dependencies: ["PersonalLLMCore"],
            path: "Tests/PersonalLLMCoreTests"
        ),
    ]
)
