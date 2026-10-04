// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Muttniks",
    platforms: [.iOS(.v27), .tvOS(.v27), .watchOS(.v27), .macCatalyst(.v27), .macOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Muttniks",
            targets: ["Muttniks"]
        ),
        .library(
            name: "MuttniksUIKit",
            targets: ["MuttniksUIKit"]
        ),
        .library(
            name: "MuttniksJSON",
            targets: ["MuttniksJSON"]
        ),
        .executable(
            name: "muttniks",
            targets: ["MuttniksCLI"]
        ),
        .library(
            name: "StateBlaster",
            targets: ["StateBlaster"]
        ),
        .executable(
            name: "StateBlasterClient",
            targets: ["StateBlasterClient"]
        ),
        .library(
            name: "Do",
            targets: ["Do"]
        ),
        .library(
            name: "ObservableUserDefaults",
            targets: ["ObservableUserDefaults"]
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
            name: "Muttniks",
            dependencies: ["MuttniksMacros", "MuttniksParsers", "CSQLite"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        .target(
            name: "MuttniksUIKit",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),
        .target(
            name: "MuttniksJSON",
            dependencies: ["Muttniks", "MuttniksParsers"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "MuttniksCLI",
            dependencies: ["Muttniks"],
            resources: [.copy("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "MuttniksTests",
            dependencies: ["Muttniks", "MuttniksParsers"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        .target(
            name: "StateBlasterPresentationParser"
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

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "StateBlasterClient",
            dependencies: [
                "StateBlaster",
                "Do",
                "ObservableUserDefaults",
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
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
            name: "ObservableUserDefaultsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "ObservableUserDefaults",
            dependencies: ["ObservableUserDefaultsMacros"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        ),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "ObservableUserDefaultsTests",
            dependencies: [
                "ObservableUserDefaults",
                "ObservableUserDefaultsMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
        .testTarget(
            name: "ObservableUserDefaultsMacrosTests",
            dependencies: [
                "ObservableUserDefaults",
                "ObservableUserDefaultsMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
                .swiftLanguageMode(.v5),
            ],
        ),
    ],
    swiftLanguageModes: [.v5],
)
