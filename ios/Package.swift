// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenWebUI",
    platforms: [
        .iOS(.v18),  // iOS 18+ required for FoundationModels framework
        .macOS(.v15) // macOS 15+ required for FoundationModels framework
    ],
    products: [
        .library(
            name: "OpenWebUI",
            targets: ["OpenWebUI"]),
    ],
    dependencies: [
        // Note: FoundationModels is a system framework, no package dependency needed
        // It will be imported directly in Swift files
        
        // Networking and API utilities
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        
        // WebSocket support for real-time features
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),
        
        // Markdown rendering
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0"),
        
        // Keychain access
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0"),
    ],
    targets: [
        .target(
            name: "OpenWebUI",
            dependencies: [
                "Alamofire",
                "Starscream",
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                "KeychainAccess",
            ]),
        .testTarget(
            name: "OpenWebUITests",
            dependencies: ["OpenWebUI"]),
    ]
)
