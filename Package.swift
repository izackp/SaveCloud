// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SaveCloud",
    platforms: [
       .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SaveCloud",
            targets: ["App"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
        .package(url: "https://github.com/groue/GRDB.swift.git", branch: "master"),
        .package(url: "https://github.com/tmthecoder/Argon2Swift.git", branch: "main"),
        .package(url: "https://github.com/Kitura/Swift-JWT.git", from: "4.0.1"),
        .package(path: "/Users/isaacpaul/Projects/swift-projects/GenHTML5"),
        .package(path: "/Users/isaacpaul/Projects/swift-projects/HRW"),
        .package(url: "https://github.com/izackp/CRLogging.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Argon2Swift", package: "Argon2Swift"),
                .product(name: "SwiftJWT", package: "Swift-JWT"),
                .product(name: "HRW", package: "hrw"),
                .product(name: "CRLogging", package: "CRLogging")
            ],
            //resources: [ .copy("Public/style.css"), ],
            swiftSettings: swiftSettings,
            plugins: [
                .plugin(name: "BindingPlugin", package: "HRW")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
