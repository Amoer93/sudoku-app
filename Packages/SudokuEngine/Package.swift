// swift-tools-version: 6.2
// 纯逻辑引擎。界面在 SudokuApp，不要把 SwiftUI 加进这个包。

import PackageDescription

let package = Package(
    name: "SudokuEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "SudokuEngine", type: .static, targets: ["SudokuEngine"]),
    ],
    targets: [
        .target(name: "SudokuEngine"),
        .testTarget(name: "SudokuEngineTests", dependencies: ["SudokuEngine"]),
    ],
    swiftLanguageModes: [.v5]
)
