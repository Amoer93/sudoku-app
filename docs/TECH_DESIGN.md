# 技术设计

**原则：App 轻量；优先级依次为 稳定 > 界面友好 > 响应迅速。逻辑尽量简单，能不用的依赖就不用。**

## 1. 总体架构
```
SwiftUI 视图 ──> ViewModel ──> SudokuEngine（纯逻辑 Swift Package）
                        ├──> BoardVision（Vision/Core ML，设备端）
                        ├──> LocalStore（本地存储）
                        └──> APIClient（可选，离线优先）
```
- 全部核心功能离线可用，网络只用于题库更新和排行榜。
- 引擎无 UI 依赖，便于测试，也可在服务端复用（Swift on Server 或移植）。

## 2. 模块
| 模块 | 目录 | 负责角色 |
|---|---|---|
| App/UI | `SudokuApp/` | iOS 开发 |
| 引擎 | `Packages/SudokuEngine/` | 算法 |
| 识别 | `Packages/BoardVision/` | 视觉识别 |
| 后端 | `Backend/` | 后端与题库 |
| 题库工具 | `PuzzleTools/` | 后端与题库 |
| 测试 | `Tests/` | 测试 |

## 3. 数据模型
```swift
struct Rules: Codable { let size: Int; let boxRows: Int?; let boxCols: Int? } // 5×5 时 box 为 nil
struct Grid: Codable { var cells: [Int] }        // 长度 size*size，0 表示空
struct Move: Codable { let index: Int; let value: Int; let layer: Int; let time: TimeInterval }
struct Puzzle: Codable { let id: String; let rules: Rules; let givens: Grid; let difficulty: Int }
```
预设：4×4 (2×2 宫)、9×9 (3×3 宫)、5×5 (无宫)；6×6 用 2×3 宫即可扩展。
候选数用位掩码（`UInt16`）表示，简单高效。

## 4. 图层系统
- `layers: [Layer]`，第 0 层为主盘；每次“假设”压入新层，记录假设格与值。
- 每层只存本层填写的格子（差量），显示时自底向上合成。
- 显示：当前层不透明，下层依次降低透明度（例如 100% / 60% / 40%），并用颜色区分层级。
- 操作：撤销本层一步、放弃本层（弹出）、确认本层（合并到下层）。出现矛盾时提示并建议放弃本层。
- 状态为值类型，撤销通过保存操作栈实现，避免复杂的共享可变状态。

## 5. 提示算法
1. 先算所有格的候选数。
2. 按从简单到难的顺序尝试技巧：唯余 → 隐性唯一 → 区块排除 → 数对。找到第一个确定结论就返回：格子、值、技巧名、依据格。
3. 若无确定格：返回最佳假设格。评分 = 候选数最少优先；并列时取所在行/列/宫空格最多（影响最大）；候选值按在相关区域出现频次排序。
4. 绝不对不确定的格子给“答案”。
求解：约束传播 + 回溯（选候选最少的格）；唯一解检测在找到 2 个解时停止。

## 6. OCR 流程
1. 预处理：灰度、自适应阈值。
2. Vision `VNDetectRectanglesRequest` 找棋盘，透视校正为正方形。
3. 尺寸判定：分析网格线数量与粗线位置（判断是否有宫）。
4. 切分格子，每格识别数字（Vision 文字识别，必要时换小型 Core ML 模型）。
5. 输出数字与置信度；低于阈值的格标记，交给用户修正。
6. 用引擎检查：无解或多解时提示用户核对。
照片只在设备端处理，不上传。

## 7. 后端 API
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/v1/puzzles?since={version}` | 增量题库 |
| POST | `/v1/scores` | `{puzzleId, moves, timeMs}`，服务端校验 |
| GET | `/v1/leaderboard/{puzzleId}` | 按步数升序，同步数按用时 |
后端尽量用托管方案（如简单的无服务器 + 数据库），减少运维。

## 8. 存储
- 内置题库：App 包内 JSON。
- 进度、记录、设置：本地 SwiftData 或 JSON 文件（选更简单稳定的一个，P0 决定）。
- 下载的题库：缓存目录，带版本号。

## 9. 性能目标
| 指标 | 目标 |
|---|---|
| 冷启动 | < 1.5s |
| 输入响应 | < 16ms（不掉帧） |
| 9×9 求解 / 提示 | < 50ms |
| 拍照识别 | < 1s |
| 安装包 | < 30MB |
| 崩溃率 | < 0.1% |
重计算放后台线程，主线程只做 UI。
