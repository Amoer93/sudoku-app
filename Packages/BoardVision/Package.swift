// swift-tools-version: 6.2
// 拍照识别的纯逻辑层。界面在 SudokuApp，不要把 SwiftUI 加进这个包。

import PackageDescription

let package = Package(
    name: "BoardVision",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(name: "BoardVision", type: .static, targets: ["BoardVision"]),
    ],
    targets: [
        .target(name: "BoardVision"),
        .testTarget(name: "BoardVisionTests", dependencies: ["BoardVision"]),
    ],
    swiftLanguageModes: [.v5]
)
