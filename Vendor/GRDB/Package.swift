// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "GRDB",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        .library(name: "GRDB", targets: ["GRDB"]),
    ],
    targets: [
        .systemLibrary(
            name: "GRDBSQLite",
            path: "Sources/GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]
        ),
        .target(
            name: "GRDB",
            dependencies: ["GRDBSQLite"],
            path: "GRDB",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_SNAPSHOT"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
