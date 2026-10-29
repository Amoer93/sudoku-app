# SudokuEngine

数独规则和求解的纯 Swift 包。没有 UI，也不依赖第三方库。

P1 的这一步只冻结公开接口。`Rules`、`Grid`、`CellIndex` 的构造和 `Codable` 已经实现。
`conflicts`、`solve`、`solutionCount` 的函数体仍是 `fatalError("TODO")`，约束传播和回溯在下一个 PR。
在那之前不要从 App 调用这三个函数。

产品类型是静态库，App 直接链接，不单独嵌入动态框架。

## 公开接口

三种规格的宫约束是固定的：

| 预设 | 边长 | 宫 |
|---|---|---|
| `Rules.fourByFour` | 4 | 2×2 |
| `Rules.fiveByFive` | 5 | 无（拉丁方，只有行列） |
| `Rules.nineByNine` | 9 | 3×3 |

- `Rules`：`size`、`boxRows`、`boxCols`。`hasBoxes` 由宫尺寸推导。编码键是这三个字段。
- `Grid`：`cells: [Int]`，行优先，`0`（`Grid.emptyCell`）表示空，已填数字是 `1...size`。下标是 `grid[row:column:]` 和 `grid[cellIndex]`。
- `CellIndex`：`row`、`column`，以及 `linearIndex(size:)`。
- `conflicts(in:rules:) -> Set<CellIndex>`：同一行、列、宫里重复的非空数字，相关格子都返回。
- `solve(_:rules:) -> Grid?`：有解时返回一个完整盘面，无解返回 nil。不判断唯一性。
- `solutionCount(_:rules:limit:) -> Int`：最多数到 `limit`。唯一性检查传 `2`。

以上类型都是 `Codable`、`Sendable` 的值类型。`grid.size` 必须等于 `rules.size`。
9×9 求解的目标是在 iPhone 上小于 50ms，实现 PR 里验收。

在仓库根目录运行：

```bash
swift test --package-path Packages/SudokuEngine
```

`Package.swift` 里的 macOS 15 只为了在 Mac 上跑测试。产品最低系统是 iOS 26。
