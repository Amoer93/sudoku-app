# Board

P1 的可玩棋盘。源码在 App 目标里的 `SudokuApp/Features/Board/`（完整路径 `SudokuApp/SudokuApp/Features/Board/`），Xcode 会跟着这个同步目录编译。本文件只作说明。

## 现在能做什么

- 首页选择 4×4、5×5、9×9。4×4 和 9×9 画粗宫线，5×5 只有普通格线和外框。
- 点格子，用数字键盘输入。题目给定的格子不能改。
- 选中高亮、冲突高亮、撤销、重做、清除当前格、清空自己填的数字。
- 「自动解题」在后台线程问引擎，再把结果填回棋盘。

## 引擎替身

`main` 上的 `SudokuEngine` 还是 P0 占位，接口 PR 还没合并，所以这里不调用它，也不写求解。

本地协议是 `SudokuBoardEngine`：

- `conflicts(in:rules:) -> Set<Int>`
- `solve(_:rules:) -> Grid?`
- `solutionCount(_:rules:) -> Int`

`Rules` 和 `Grid` 的字段与 `docs/TECH_DESIGN.md` 一致：`size`、`boxRows`、`boxCols`、`cells`。5×5 的宫为 `nil`。

`FixtureBoardEngine` 只认识三道写死的示例。冲突是「和示例答案不一样的格子」，求解是把那盘答案交回去。这不是行列宫扫描，也不是搜索。

## 换成真引擎

1. 引擎类型的字段一致时，删除 `EngineStandIn.swift` 里的 `Rules` 和 `Grid`，改为 `import SudokuEngine`。
2. 写一个适配器实现 `SudokuBoardEngine`，转调引擎的 `conflicts`、`solve`、`solutionCount`。
3. 把 `BoardScreen` 的默认引擎从 `FixtureBoardEngine()` 换成这个适配器。
4. `BoardViewModel` 和视图不用改。

如果引擎最终用的是角色文档草案里的 `boxShape`，而不是 `boxRows` / `boxCols`，只改 `Rules.boxSpan` 和适配器的字段映射。宫线仍然看 `boxSpan`：竖线用列数，横线用行数。
