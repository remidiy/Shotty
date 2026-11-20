// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Shotty",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "Shotty",
            path: "Sources/Shotty",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
