# SudokuApp

SwiftUI 空壳。用 Xcode 26 打开 `SudokuApp.xcodeproj`。

- 最低系统 iOS 26，见 [docs/adr/0002-ios-deployment-target.md](../docs/adr/0002-ios-deployment-target.md)。
- 源码在 `SudokuApp/`，测试在 `SudokuAppTests/`。
- `Features/` 只是后续界面的目录，还没有代码。
- App 目标链接了静态库 `SudokuEngine`，构建 App 时会一起编译引擎。首页源码还没有 `import` 它，规则调用从 P1 开始。
- 签名团队还没填。模拟器上测试时可以关签名：`CODE_SIGNING_ALLOWED=NO`。
- Bundle ID `app.sudoku.SudokuApp` 是占位，上架前再换成正式的。
