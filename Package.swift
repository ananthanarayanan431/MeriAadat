// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Aadat",
    platforms: [
        // MenuBarExtra and SMAppService require macOS 13.
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Aadat", targets: ["Aadat"])
    ],
    targets: [
        // The day board and its storage. Foundation only, so it can be unit tested.
        .target(
            name: "AadatCore"
        ),
        // The menu bar app: SwiftUI, AppKit, ServiceManagement.
        .executableTarget(
            name: "Aadat",
            dependencies: ["AadatCore"]
        ),
        .testTarget(
            name: "AadatCoreTests",
            dependencies: ["AadatCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
