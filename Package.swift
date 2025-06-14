// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuiverDB",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "quiverdb", targets: ["QuiverDB"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-vapor.git", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/waynewbishop/bishop-algorithms-quiver-package.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "QuiverDB",
            dependencies: [
                .product(name: "Quiver", package: "bishop-algorithms-quiver-package"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIVapor", package: "swift-openapi-vapor"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ],
            path: "Sources/QuiverDB",  // Explicitly specify path
            resources: [
                .copy("Resources/")
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .testTarget(
            name: "QuiverDBTests",
            dependencies: [
                "QuiverDB",  // Reference to the main target
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "Quiver", package: "bishop-algorithms-quiver-package")
            ],
            path: "Tests/QuiverDBTests"  // Explicitly specify test path
        )
    ]
)
