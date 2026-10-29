# 数独 App

iOS 数独应用。产品说明、阶段计划和角色分工在 [docs/README.md](docs/README.md)。

## 当前阶段

P0：仓库、空壳 App、引擎包和 CI 已就位。玩法从 P1 开始。

## 已定事项

- 最低系统：**iOS 26.0**。说明见 [docs/adr/0002-ios-deployment-target.md](docs/adr/0002-ios-deployment-target.md)。
- 进度、记录、设置用 **JSON 文件**，不用 SwiftData。说明见 [docs/adr/0001-local-storage.md](docs/adr/0001-local-storage.md)。

## 目录

| 路径 | 内容 |
|---|---|
| `SudokuApp/` | SwiftUI App。用 Xcode 打开 `SudokuApp/SudokuApp.xcodeproj` |
| `Packages/SudokuEngine/` | 纯逻辑引擎（Swift Package） |
| `Packages/BoardVision/` | 识别模块，P4 再实现 |
| `Backend/` | 题库与排行榜服务，P5 再实现 |
| `PuzzleTools/` | 题目生成脚本，P3 再实现 |
| `Tests/` | 跨模块测试和 OCR 样本，后续阶段使用 |
| `.github/workflows/ci.yml` | 构建、单元测试、SwiftLint、SwiftFormat |
| `docs/` | 计划、设计、约定、决策和测试报告 |

## 本地检查

```bash
swift test --package-path Packages/SudokuEngine
swiftlint lint --strict
swiftformat --lint .
```

App 测试需要 macOS 和 Xcode 26：

```bash
xcodebuild test \
  -project SudokuApp/SudokuApp.xcodeproj \
  -scheme SudokuApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

模拟器名称以本机 `xcrun simctl list devices available` 为准。CI 会自动选一台可用的 iPhone 模拟器。

协作方式见 [CONTRIBUTING.md](CONTRIBUTING.md)。
