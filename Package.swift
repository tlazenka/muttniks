// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Puzzola",
    platforms: [.iOS(.v27), .tvOS(.v27), .watchOS(.v27), .macCatalyst(.v27), .macOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Puzzola",
            targets: ["Puzzola"]
        ),
        .library(
            name: "PuzzolaUIKit",
            targets: ["PuzzolaUIKit"]
        ),
        .library(
            name: "PuzzolaJSON",
            targets: ["PuzzolaJSON"]
        ),
        .executable(
            name: "puzzola",
            targets: ["PuzzolaCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "604.0.0-latest")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .systemLibrary(
            name: "CSQLite",
            providers: [
                .apt(["libsqlite3-dev"])
            ]
        ),
        .target(
            name: "PuzzolaParsers",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "PuzzolaMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PuzzolaParsers",
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "Puzzola",
            dependencies: ["PuzzolaMacros", "PuzzolaParsers", "CSQLite"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        .target(
            name: "PuzzolaUIKit",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        .target(
            name: "PuzzolaJSON",
            dependencies: ["Puzzola", "PuzzolaParsers"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "PuzzolaCLI",
            dependencies: ["Puzzola"],
            resources: [.copy("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "PuzzolaTests",
            dependencies: ["Puzzola", "PuzzolaParsers"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
    ]
)
