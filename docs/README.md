# 数独解题 App 项目总览

## 产品目标
一款 iOS 数独 App，最终上架 Apple App Store。核心功能：
- **拍照识题**：拍照/相册导入，自动识别棋盘尺寸与数字，支持手动修正。
- **多尺寸**：4×4、9×9（标准宫格）、5×5（拉丁方：仅行列不重复，无宫）。引擎规则可配置（宫约束开/关），可扩展到 6×6 等。
- **自动解题**。
- **提示系统**：只对“可确定答案”的格子给逻辑提示，并说明所用技巧；无确定格时，推荐“最佳假设格”（候选数最少/影响最大）。
- **多层假设图层**：每次假设新建一个半透明图层，可多层嵌套叠加，按层撤销/确认。
- **最佳记录排行榜**：按解题步数排名，同时记录用时。
- **内置题库**：持续更新。

## 核心文档
- [DEV_PLAN.md](DEV_PLAN.md)：分阶段开发计划（P0–P6，小步迭代，同时只推进 1–2 个阶段）
- [TECH_DESIGN.md](TECH_DESIGN.md)：技术设计
- [CONVENTIONS.md](CONVENTIONS.md)：开发约定（代码英文，注释和文档中文；简单稳定优先）
- [daily-reports/](daily-reports/README.md)：每日日报与汇总

## 角色索引
| # | 角色 | 文档 |
|---|---|---|
| 1 | 总工程师 | [roles/01-chief-engineer.md](roles/01-chief-engineer.md) |
| 2 | iOS 开发工程师 | [roles/02-ios-developer.md](roles/02-ios-developer.md) |
| 3 | 算法工程师 | [roles/03-algorithm-engineer.md](roles/03-algorithm-engineer.md) |
| 4 | 视觉识别工程师 | [roles/04-vision-engineer.md](roles/04-vision-engineer.md) |
| 5 | 后端与题库工程师 | [roles/05-backend-puzzlebank-engineer.md](roles/05-backend-puzzlebank-engineer.md) |
| 6 | 测试工程师 | [roles/06-test-engineer.md](roles/06-test-engineer.md) |
| 7 | 代码审查工程师 | [roles/07-code-reviewer.md](roles/07-code-reviewer.md) |

## 当前分工
| 角色 | 负责 agent | 建议模型能力 | 备注 |
|---|---|---|---|
| 总工程师 | Ari | 高 | 架构、拆任务、集成、合并把关 |
| iOS 开发 | A厂金牌码农 | 中高（性价比即可） | 与视觉识别兼任 |
| 视觉识别 | A厂金牌码农 | 高（最强档） | |
| 算法 | C厂全能王 | 最高 | 算法代码由 A 审查 |
| 代码审查 | C厂全能王 | 高（最强档） | 审查 A 与 D 的代码 |
| 后端与题库 | D厂性价比之王 | 中（性价比即可） | |
| 测试 | **待配置**（如 Kimi） | 中（性价比即可） | 配置前由 D 临时兼任 |

> token 消耗未做实测，仅为相对估计；开工后以实际用量校准。

**铁律：作者不得审查自己的代码。** Ari 写的代码由 C 审查；C 的算法代码由 A 审查。

## 协作流程
1. **拆任务**：Ari 把需求拆成小任务卡（负责人、涉及模块、接口、完成标准、依赖）。
2. **模块独占**：同一时间每个模块/目录只有一个负责人在改；跨模块改动须先经 Ari 协调。
3. **分支开发**：每个任务一个分支 `feat/<模块>-<简述>`，小步提交。
4. **自测**：提交前本地通过单元测试与 SwiftLint。
5. **PR**：PR 描述写清改动、接口变化、测试情况，关联任务卡。
6. **CI + 审查**：CI 全绿 + 非作者审查通过。
7. **合并**：Ari 作为合并闸门做最终集成确认后合并到 `main`。
8. **日报**：每个 AI 每天写日报，Ari 汇总（见 daily-reports）。
9. **交接**：任务结束更新对应角色文档的“交接说明”和 `docs/` 中的接口文档。

## 建议目录结构
```
SudokuApp/            iOS App（SwiftUI）
  Features/Board, Layers, Hints, Leaderboard, Camera
Packages/SudokuEngine/   解题/提示/评级引擎（Swift Package，纯逻辑）
Packages/BoardVision/    识别模块（Vision/Core ML）
Backend/                 题库与排行榜服务
PuzzleTools/             题目生成与评级脚本
Tests/                   跨模块测试、OCR 样本集
.github/workflows/       CI
docs/                    文档
```

## 新 agent 接手指南
先读本 README、CONVENTIONS、DEV_PLAN 当前阶段，再读对应角色文档，再看最近的任务卡与已合并 PR，最后向 Ari 确认当前分配的任务后再动手。
