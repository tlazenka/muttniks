// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Fetcher",
    dependencies: [
		.package(path: "../Shared"),
    ],
    targets: [
        .target(
            name: "Fetcher",
            dependencies: ["Shared"]),
        .testTarget(
            name: "FetcherTests",
            dependencies: ["Fetcher"]),
    ]
)
