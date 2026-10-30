# Board

P1 的可玩棋盘。源码在 App 目标里的 `SudokuApp/Features/Board/`（完整路径 `SudokuApp/SudokuApp/Features/Board/`），Xcode 会跟着这个同步目录编译。本文件只作说明。

## 现在能做什么

- 首页选择 4×4、5×5、9×9。4×4 和 9×9 画粗宫线，5×5 只有普通格线和外框。
- 点格子，用数字键盘输入。题目给定的格子不能改。
- 选中高亮、冲突高亮、撤销、重做、清除当前格、清空自己填的数字。
- 「自动解题」在后台线程问引擎，再把结果填回棋盘。
- 解的个数按当前盘面在后台重算，`limit` 固定为 2。自动解题计数的是求解前的盘面，不会对填满后的结果再数一次。

## 引擎替身

PR #2 冻结了 `SudokuEngine` 的公开接口，PR #6 已把求解器合入 `main`。App 默认仍用下面的替身，切换步骤见文末。

App 内的 `SudokuBoardEngine` 与冻结接口一致：

- `conflicts(in:rules:) -> Set<CellIndex>`
- `solve(_:rules:) -> Grid?`
- `solutionCount(_:rules:limit:) -> Int`

`Rules` 用 `boxRows` / `boxCols`，`init(size:boxRows:boxCols:)` 会抛错。`Grid.cells` 是 `[Int]`，`0` 是空格，写入走下标。`conflicts` 是轻量同步调用，可以在主线程用。

`FixtureBoardEngine` 只认识三道写死的示例。冲突是「和示例答案不一样的格子」，求解是把那盘答案交回去。这不是行列宫扫描，也不是搜索。

## 换成真引擎

`EngineBoardAdapter.swift` 已经 `import SudokuEngine`，按 K 的建议保留 App 自己的 `Rules`/`Grid`/`CellIndex`，适配器负责转换：

- 用 `try?` 构造引擎的 `Rules`/`Grid`，失败按无冲突、无解、0 个解处理，不用 `try!`。
- 转换前先校验 `grid.size == rules.size` 和 `cells.count == size * size`，不会触发引擎的 precondition。
- `CellIndex` 行列一一对应，不做下标换算。

求解器已经合入，切换清单：

- 把 `BoardScreen` / `BoardViewModel` 的默认引擎换成 `EngineBoardAdapter()`。
- 改掉 `BoardCopy` 里写死的「示例」文案（如「已填入示例解。」），多解提示注明是「原题」有多个解。
- 删掉 `FixtureBoardEngine` 和只给替身用的示例答案。
