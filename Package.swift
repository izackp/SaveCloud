// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SaveCloud",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/JohnSundell/Plot.git", from: "0.14.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", branch: "master"),
        .package(url: "https://github.com/tmthecoder/Argon2Swift.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Plot", package: "plot"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Argon2Swift", package: "Argon2Swift")
            ],
            //resources: [ .copy("style.css"), ],
            swiftSettings: swiftSettings
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
