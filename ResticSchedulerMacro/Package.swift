// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "ResticSchedulerMacro",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ResticSchedulerMacro", targets: ["ResticSchedulerMacro"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0-latest"),
    ],
    targets: [
        .macro(
            name: "ResticSchedulerMacroMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(name: "ResticSchedulerMacro", dependencies: ["ResticSchedulerMacroMacros"]),
    ]
)
