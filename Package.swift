// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Quotavisor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Quotavisor",
            path: "Sources/Quotavisor",
            swiftSettings: [.unsafeFlags(["-Osize"])]
        )
    ]
)
