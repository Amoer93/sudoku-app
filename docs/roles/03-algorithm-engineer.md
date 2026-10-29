# 角色：算法工程师

**当前负责人：C厂全能王**（本角色代码由 A厂金牌码农 审查）

## 使命
提供正确、快速、可解释的数独引擎，是提示系统的核心。

## 职责
- 规则可配置：尺寸 N、是否启用宫约束、宫形状；5×5 为拉丁方（仅行列）；可扩展到 6×6（2×3 宫）等。
- 自动求解（约束传播 + 回溯/DLX），唯一解校验、无解检测。
- **逻辑提示**：只给可确定答案的格子，并返回所用技巧（唯余、隐性唯一、数对、区块排除、X-Wing 等）及推理依据格。
- **最佳假设格**：无确定格时，按“候选数最少，其次影响最大（关联格数/传播后消除量）”评分推荐，给出候选值顺序。
- 难度评级：按所需技巧与假设深度打分。
- 用户步数合法性校验（供排行榜防作弊）。

## 负责模块
`Packages/SudokuEngine/`（纯 Swift，无 UI 依赖），`PuzzleTools/` 中的评级逻辑。

## 接口（草案）
```swift
struct Rules { let size: Int; let boxShape: (rows: Int, cols: Int)? }
func solve(_ g: Grid, _ r: Rules) -> SolveResult      // .unique/.multiple/.none
func nextHint(_ g: Grid, _ r: Rules) -> Hint?         // cell, value, technique, reasons
func bestAssumptionCell(_ g: Grid, _ r: Rules) -> Assumption?
func rate(_ g: Grid, _ r: Rules) -> Difficulty
func verifyMoves(_ puzzle: Grid, _ moves: [Move], _ r: Rules) -> Bool
```

## 交付物
引擎包、技巧说明文档、性能基准。

## 完成标准
单元测试覆盖所有技巧；万级题目批量验证结果 100% 正确；9×9 求解在 iPhone 上 <50ms。

## 质量标准
提示绝不给出不可确定的答案；纯函数、可测试；公共接口有文档注释。

## 交接说明
技巧清单与实现状态维护在 `Packages/SudokuEngine/TECHNIQUES.md`；评分公式变更需留 ADR。

## 建议模型能力
最高（最强模型）。

## 相关文档
- 开发约定：[../CONVENTIONS.md](../CONVENTIONS.md)（必读）
- 开发计划：[../DEV_PLAN.md](../DEV_PLAN.md)
- 技术设计：[../TECH_DESIGN.md](../TECH_DESIGN.md)
- 日报：[../daily-reports/README.md](../daily-reports/README.md)，每个工作日提交日报
