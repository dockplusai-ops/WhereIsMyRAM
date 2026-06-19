// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "WhereIsMyRAM",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "WhereIsMyRAM",
            path: "Sources/WhereIsMyRAM",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
