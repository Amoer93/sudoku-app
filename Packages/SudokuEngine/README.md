# SudokuEngine

数独规则、求解、提示和评级的纯 Swift 包。没有 UI，也不依赖第三方库。

P0 只有占位类型 `EnginePlaceholder` 和对应测试。规则和求解从 P1 开始。产品类型是静态库，App 直接链接，不单独嵌入动态框架。

在仓库根目录运行：

```bash
swift test --package-path Packages/SudokuEngine
```

`Package.swift` 里的 macOS 15 只为了在 Mac 上跑测试。产品最低系统是 iOS 26。
