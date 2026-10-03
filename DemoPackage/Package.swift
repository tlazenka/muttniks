// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "DemoPackage",
    platforms: [.macOS(.v26), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .macCatalyst(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "OnboardingShared", targets: ["OnboardingShared"]),
        .library(name: "OnboardingSwiftUI", targets: ["OnboardingSwiftUI"]),
        .library(name: "OnboardingUIKitApp", targets: ["OnboardingUIKitApp"]),
        .library(name: "OnboardingSwiftUIApp", targets: ["OnboardingSwiftUIApp"]),
    ],
    dependencies: [
        .package(name: "StateBlaster", path: "..")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .target(
            name: "OnboardingShared",
            dependencies: [
                .product(name: "StateBlaster", package: "StateBlaster")
            ]

        ),
        .target(
            name: "OnboardingSwiftUI",
            dependencies: ["OnboardingShared"],
        ),
        .target(
            name: "OnboardingUIKitApp",
            dependencies: ["OnboardingShared"],
            plugins: [
                .plugin(
                    name: "StateBlasterStoryboardPlugin",
                    package: "StateBlaster",
                )
            ]
        ),
        .target(
            name: "OnboardingSwiftUIApp",
            dependencies: ["OnboardingSwiftUI"],
        ),
        .testTarget(
            name: "OnboardingDemoTests",
            dependencies: [
                "OnboardingShared",
                "OnboardingSwiftUI",
                "OnboardingUIKitApp",
            ],
        ),
    ],
    swiftLanguageModes: [.v5],
)
