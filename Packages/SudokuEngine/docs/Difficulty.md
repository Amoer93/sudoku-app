# 难度评级（SE 风格）

本文说明 `DifficultyGrader` 如何给 9×9 标准数独打分、分档。

## 适用范围

- 只支持 9×9 标准数独。传入其他尺寸会触发 precondition 直接崩溃，调用方须先判断尺寸（入库接口对其他尺寸返回 `unsupportedSize`）。
- 已经填满且正确的盘面：返回简单档，`seRating` 为 0，`score` 为 0，`techniqueCounts` 为空，`hardestTechnique` 只是占位值 `nakedSingle`。

## 评级流程

1. 先用求解器确认题目有且只有一个解：无解返回 `GradeError.noSolution`，多解返回 `GradeError.multipleSolutions`。
2. 模拟人工解题：每一步按下表 SE 值从低到高依次尝试技巧，第一个能推进（填入数字或删掉候选）的技巧记一次，然后重新从最简单的技巧开始。
3. 所有技巧都用不上时，记一次 `trialAndError`（试数），按唯一解在候选最少的空格（同数取下标最小）填入正确数字，再继续人工推理。

## SE 基准值表

| 技巧 | `Technique` | SE 值 | 档位 |
| --- | --- | --- | --- |
| 隐性唯一（宫内） | `hiddenSingle` | 1.2 | 简单 |
| 隐性唯一（行、列） | `hiddenSingle` | 1.5 | 简单 |
| 唯一候选数 | `nakedSingle` | 2.3 | 简单 |
| 区块摒除（宫→行列） | `pointing` | 2.6 | 中等 |
| 区块摒除（行列→宫） | `boxLineReduction` | 2.8 | 中等 |
| 显性数对 | `nakedPair` | 3.0 | 中等 |
| X-Wing | `xWing` | 3.2 | 中等 |
| 隐性数对 | `hiddenPair` | 3.4 | 中等 |
| 显性三数组 | `nakedTriple` | 3.6 | 困难 |
| 剑鱼 | `swordfish` | 3.8 | 困难 |
| 隐性三数组 | `hiddenTriple` | 4.0 | 困难 |
| XY-Wing | `xyWing` | 4.2 | 困难 |
| 显性四数组 | `nakedQuad` | 5.0 | 专家 |
| 隐性四数组 | `hiddenQuad` | 5.4 | 专家 |
| 单数字染色 | `simpleColoring` | 6.5 | 专家 |
| 试数 | `trialAndError` | 11.0 | 专家 |

数值都集中在 `Sources/SudokuEngine/SERatings.swift` 一处维护。

## 分档阈值

`seRating` 取解题过程中实际用到的技巧的最高 SE 值，再按下面的阈值分档（`Difficulty.difficulty(forSERating:)`）：

- 简单 `easy`：≤ 2.3
- 中等 `medium`：2.4 – 3.4
- 困难 `hard`：3.5 – 4.4
- 专家 `expert`：> 4.4，或者用到了 `trialAndError`

`Technique.difficulty` 也由该技巧的 SE 值按同一阈值推出。因此和最初按“技巧类别”的分档相比有几处变化：X-Wing 归中等，XY-Wing 归困难，显性/隐性四数组归专家。

## score 的含义

`score` 是整个解题过程的加权总和：每一步加上该步技巧 SE 值 × 10（四舍五入取整；宫内隐性唯一按 1.2 计）。它只用来在同一档内排序：同档题目 `score` 越高，需要的步骤越多、越难。跨档比较请用 `difficulty` 或 `seRating`。

## 来源说明

SE 基准值参考 [SukakuExplainer](https://github.com/SudokuMonster/SukakuExplainer)（Sudoku Explainer 的分支）中各 Rule/Hint 类的难度常数。这里只引用了数字，没有复制任何代码（该项目代码为 LGPL 许可）。技巧实现全部为本项目自写。

与 SE 原版的差异：

- `simpleColoring`：目前只实现单数字染色，不实现 X 链、强制链等更长的链。取 SE 链类技巧的起点 6.5，仍归专家档。
- `trialAndError`：SE 没有这一项。本项目给超出技巧库的题取 11.0，并一律归为专家，保证用户上传的难题也能入库。
- 本项目没有实现 SE 中的 XYZ-Wing、Jellyfish、唯一矩形等技巧，遇到时会落到更高的技巧或试数，评分可能比 SE 偏高。

## 题库（PuzzleBank）

`PuzzleBank` 是 9×9 标准数独的本地题库模型。每条记录 `PuzzleBankEntry` 包含规范指纹 `id`、题目尺寸、`givens`（行优先，0 表示空格）、难度、SE 评分、加权总分、来源与入库时间。指纹来自 `PuzzleCanonicalizer.fingerprint`，保证几何对称与数字重标后的等价题目只占用同一个条目。

### 入库流程

调用 `PuzzleBank.add(_:rules:source:now:)` 时：

1. 先校验 `rules == .nineByNine` 且 `grid.size == 9`，否则返回 `.unsupportedSize`。
2. 计算指纹；若题库中已存在相同指纹，返回 `.duplicate(existing:)`。
3. 调用 `DifficultyGrader.grade`；无解或多解分别返回 `.ungradable(.noSolution)` / `.ungradable(.multipleSolutions)`。
4. 成功则追加记录并返回该记录。

### 排序与 tie-break

`PuzzleBank.entries(difficulty:source:sort:)` 支持以下排序：

- `difficultyAscending`：难度升序，同档按 `score` 升序，再按 `id.value` 升序。
- `difficultyDescending`：难度降序，同档按 `score` 降序，再按 `id.value` 升序。
- `addedAtNewest` / `addedAtOldest`：按 `addedAt` 新/旧排序，相同时间按 `id.value` 升序。
- `sourceThenDifficulty`：先按来源（`builtin` 在前），再难度升序、`score` 升序、`id.value` 升序。

### 持久化与内置去重

用户上传题目通过 `userEntriesData()` 编码为 JSON（ISO 8601 日期、键按字母序），仅包含 `source == .userUpload` 的条目。应用负责写入文件。启动时使用 `PuzzleBank.load(builtinBundle:userData:)`：先加载 `BuiltinPuzzles.json`，再解码用户数据，丢弃来源不是 `.userUpload` 的条目以及与内置/前面条目重复的题目。
