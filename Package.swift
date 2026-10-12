// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Muttniks",
    platforms: [.iOS(.v18), .tvOS(.v18), .watchOS(.v11), .macCatalyst(.v18), .macOS(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "StateBlaster",
            targets: ["StateBlaster"]
        ),
        .library(
            name: "Do",
            targets: ["Do"]
        ),
        .library(
            name: "ScopedUserDefaults",
            targets: ["ScopedUserDefaults"]
        ),
        .library(name: "OnboardingFeature", targets: ["OnboardingFeature"]),
        .library(name: "SQLiteJSONBlaster", targets: ["SQLiteJSONBlaster"]),
        .library(name: "QueryBlaster", targets: ["QueryBlaster"]),
        .library(name: "SemanticCore", targets: ["SemanticCore"]),
        .library(name: "ScopedUserDefaults", targets: ["ScopedUserDefaults"]),
        .library(name: "MuttniksStateMachines", targets: ["MuttniksStateMachines"]),
        .library(name: "CBLinearHierarchy", targets: ["CBLinearHierarchy"]),
        .library(name: "Do", targets: ["Do"]),
        .executable(name: "earthquakes", targets: ["EarthquakesCLI"]),
        .executable(name: "feed-server", targets: ["FeedServer"]),
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
            name: "MuttniksParsers",
            dependencies: ["Do"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "MuttniksMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "MuttniksParsers",
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "SQLiteJSONBlaster",
            dependencies: [
                "MuttniksMacros",
                "MuttniksParsers",
                "CSQLite",
                "SemanticCore",
                "QueryBlaster",
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        .macro(
            name: "StateBlasterMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "StateBlaster",
            dependencies: ["StateBlasterMacros"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(.some(MainActor.self)),

            ],
        ),

        .target(
            name: "StateBlasterApp",
            dependencies: ["StateBlaster"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .defaultIsolation(.some(MainActor.self)),

            ],
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "StateBlasterTests",
            dependencies: [
                "StateBlaster",
                "StateBlasterMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        .testTarget(
            name: "StateBlasterMacrosTests",
            dependencies: [
                "StateBlaster",
                "StateBlasterMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
        .testTarget(
            name: "StateBlasterAppTests",
            dependencies: [
                "StateBlasterApp"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "DoMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "Do",
            dependencies: ["DoMacros"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "DoTests",
            dependencies: [
                "Do",
                "DoMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
        .testTarget(
            name: "DoMacrosTests",
            dependencies: [
                "Do",
                "DoMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
        .macro(
            name: "ScopedUserDefaultsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "ScopedUserDefaults",
            dependencies: ["ScopedUserDefaultsMacros"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "ScopedUserDefaultsTests",
            dependencies: [
                "ScopedUserDefaults",
                "ScopedUserDefaultsMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
        .testTarget(
            name: "ScopedUserDefaultsMacrosTests",
            dependencies: [
                "ScopedUserDefaults",
                "ScopedUserDefaultsMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .target(
            name: "OnboardingFeature",
            dependencies: [
                "StateBlaster"
            ]

        ),
        .testTarget(
            name: "OnboardingFeatureTests",
            dependencies: [
                "OnboardingFeature",
                "CSQLite",
                "MuttniksStateMachines",
            ],
        ),
        .target(name: "SemanticCore"),
        .target(name: "CBLinearHierarchy"),

        .macro(
            name: "MuttniksStateMachineMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "MuttniksStateMachines",
            dependencies: ["MuttniksStateMachineMacros", "CSQLite", "SemanticCore"]
        ),

        .target(name: "QueryBlaster"),
        .target(name: "PostgresBlaster", dependencies: ["QueryBlaster"]),
        .executableTarget(
            name: "FeedServer",
            dependencies: ["QueryBlaster", "PostgresBlaster"],
            path: "Demos/FeedServer"
        ),
        .executableTarget(
            name: "EarthquakesCLI",
            dependencies: ["SQLiteJSONBlaster"],
            path: "Demos/EarthquakesCLI",
            resources: [.copy("Resources/SampleData.json")]
        ),

        .testTarget(name: "SemanticCoreTests", dependencies: ["SemanticCore"]),
        .testTarget(
            name: "SQLiteJSONBlasterTests",
            dependencies: ["SQLiteJSONBlaster", "MuttniksParsers", "QueryBlaster"]
        ),
    ],
    swiftLanguageModes: [.v5],
)
