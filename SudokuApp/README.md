# SudokuApp

SwiftUI App。用 Xcode 26 打开 `SudokuApp.xcodeproj`。

- 最低系统 iOS 26，见 [docs/adr/0002-ios-deployment-target.md](../docs/adr/0002-ios-deployment-target.md)。
- 源码在 `SudokuApp/`，测试在 `SudokuAppTests/`。
- P1 棋盘在 `SudokuApp/Features/Board/`。说明见 [Features/Board/README.md](Features/Board/README.md)。
- App 目标仍然链接静态库 `SudokuEngine`。棋盘还没有 `import` 它：引擎接口未合并前，使用 App 内的 `SudokuBoardEngine` 替身。
- 签名团队还没填。模拟器上测试时可以关签名：`CODE_SIGNING_ALLOWED=NO`。
- Bundle ID `app.sudoku.SudokuApp` 是占位，上架前再换成正式的。
