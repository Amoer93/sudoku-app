# Board

P1 的可玩棋盘。源码在 App 目标里的 `SudokuApp/Features/Board/`（完整路径 `SudokuApp/SudokuApp/Features/Board/`），Xcode 会跟着这个同步目录编译。本文件只作说明。

## 现在能做什么

- 首页选择 4×4、5×5、9×9。4×4 和 9×9 画粗宫线，5×5 只有普通格线和外框。
- 点格子，用数字键盘输入。题目给定的格子不能改。
- 选中高亮、冲突高亮、撤销、重做、清除当前格、清空自己填的数字。
- 「自动解题」在后台线程问引擎，再把结果填回棋盘。
- 解的个数按当前盘面在后台重算，`limit` 固定为 2。自动解题计数的是求解前的盘面，不会对填满后的结果再数一次。

## 引擎替身

`main` 上的 `SudokuEngine` 还是 P0 占位。PR #2 把公开接口冻成了下面这组签名，但求解仍是 `fatalError`，所以这里不调用它。

App 内的 `SudokuBoardEngine` 与冻结接口一致：

- `conflicts(in:rules:) -> Set<CellIndex>`
- `solve(_:rules:) -> Grid?`
- `solutionCount(_:rules:limit:) -> Int`

`Rules` 用 `boxRows` / `boxCols`，`init(size:boxRows:boxCols:)` 会抛错。`Grid.cells` 是 `[Int]`，`0` 是空格，写入走下标。`conflicts` 是轻量同步调用，可以在主线程用。

`FixtureBoardEngine` 只认识三道写死的示例。冲突是「和示例答案不一样的格子」，求解是把那盘答案交回去。这不是行列宫扫描，也不是搜索。

## 换成真引擎

等求解实现落地、不再 `fatalError` 之后，删掉 App 里的 `Rules`、`Grid`、`CellIndex`，改为 `import SudokuEngine`。适配器只转发，不做换算：

```swift
struct SudokuEngineAdapter: SudokuBoardEngine {
    func conflicts(in grid: Grid, rules: Rules) -> Set<CellIndex> {
        SudokuEngine.conflicts(in: grid, rules: rules)
    }

    func solve(_ grid: Grid, rules: Rules) -> Grid? {
        SudokuEngine.solve(grid, rules: rules)
    }

    func solutionCount(_ grid: Grid, rules: Rules, limit: Int) -> Int {
        SudokuEngine.solutionCount(grid, rules: rules, limit: limit)
    }
}
```

然后把 `BoardScreen` 的默认引擎从 `FixtureBoardEngine()` 换成这个适配器。视图模型不用改。不要在适配器里 `try!`。
