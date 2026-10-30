# Board

P1 的可玩棋盘。源码在 App 目标里的 `SudokuApp/Features/Board/`（完整路径 `SudokuApp/SudokuApp/Features/Board/`），Xcode 会跟着这个同步目录编译。本文件只作说明。

## 现在能做什么

- 首页选择 4×4、5×5、9×9。4×4 和 9×9 画粗宫线，5×5 只有普通格线和外框。
- 点格子，用数字键盘输入。题目给定的格子不能改。
- 选中高亮、冲突高亮、撤销、重做、清除当前格、清空自己填的数字。
- 「自动筛选」开关：打开后，选中空格时同行、同列、同宫（5×5 只看行列）已有的数字变灰且不能点。没选格或选中给定格时不禁用任何数字；关闭时行为不变。计算在 App 层 `PeerValues`，不调引擎。
- 「自动解题」在后台线程问引擎，再把结果填回棋盘。
- 解的个数按当前盘面在后台重算，`limit` 固定为 2。自动解题计数的是求解前的盘面，不会对填满后的结果再数一次。

## 引擎替身

PR #2 冻结了 `SudokuEngine` 的公开接口，PR #6 已把求解器合入 `main`。App 默认已改用真引擎 `EngineBoardAdapter`，下面的替身只留给测试和 SwiftUI 预览。

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

切换已完成：

- [x] `BoardScreen` / `BoardViewModel` 的默认引擎换成 `EngineBoardAdapter()`。
- [x] `BoardCopy` 去掉「示例」字样，解的个数提示注明是「当前盘面」（计数包含玩家填入的数字，与上面的说明一致）。
- [x] `FixtureBoardEngine` 不删，只在测试和预览里显式传入。内置题目的答案保留给替身和测试核对。
- [x] 首页入口给 `BoardScreen` 加了 `.id(preset)`，换题时模型跟着重建。
