// swift-tools-version: 5.9
// RecallCore — shared business logic for the Recall app.
// Imported by: Recall (iOS app), RecallShare, RecallWidget, RecallWatch.

import PackageDescription

let package = Package(
    name: "RecallCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "RecallCore",
            targets: ["RecallCore"]
        )
    ],
    targets: [
        .target(
            name: "RecallCore",
            resources: [
                // The Core Data model ships inside the package so every
                // target (app, share extension, widget) loads the same schema.
                .process("Resources/Recall.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "RecallCoreTests",
            dependencies: ["RecallCore"]
        )
    ]
)
