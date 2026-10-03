// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PuzzolaDemo",
    platforms: [.iOS(.v27)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PuzzolaDemo",
            targets: ["PuzzolaDemo"]
        )
    ],
    dependencies: [
        .package(name: "Puzzola", path: "../")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PuzzolaDemo",
            dependencies: [
                .product(name: "Puzzola", package: "Puzzola"),
                .product(name: "PuzzolaUIKit", package: "Puzzola"),
                .product(name: "PuzzolaJSON", package: "Puzzola"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ],
        )
    ]
)
