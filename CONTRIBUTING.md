# 参与协作

先读 [docs/README.md](docs/README.md)、[docs/CONVENTIONS.md](docs/CONVENTIONS.md) 和 [docs/DEV_PLAN.md](docs/DEV_PLAN.md) 里的当前阶段，再读自己的角色文档。动手前向 Ari 确认任务。

## 语言

- 代码、文件名、分支名、提交信息用英文。
- 注释和文档用中文。

## 分支与提交

- 分支：`feat/<module>-<desc>` 或 `fix/<module>-<desc>`。
- 提交信息写清模块，例如 `engine: add hidden single technique`。
- 一个 PR 只做一件事，尽量少于 400 行改动。P0 这种搭仓库的改动可以例外。

## 代码

- 优先直白、稳定的写法。同样的逻辑出现第三次再考虑提取。
- 不引入第三方运行时依赖，除非 Ari 同意。SwiftLint 和 SwiftFormat 只用于检查，不进 App。
- 禁止强制解包（测试除外）。错误要处理或明确上抛。
- 单个函数尽量少于 40 行，单个文件尽量少于 400 行。

## 提交前

```bash
swift test --package-path Packages/SudokuEngine
swiftlint lint --strict
swiftformat --lint .
```

改了 App 的话，在 Xcode 里跑 `SudokuApp` 的单元测试。测试不能依赖网络，随机数要固定种子。

## 审查与合并

- 作者不能审查自己的代码。
- 审查意见分「必须改」和「建议」，清单见 [docs/review-checklist.md](docs/review-checklist.md)。
- 合并条件：CI 全绿 + 一位非作者审查通过 + Ari 确认。
- 接口变更先改文档，再改代码。重大决策写在 `docs/adr/`。

## 已经定下的事

- 最低系统是 iOS 26，见 [docs/adr/0002-ios-deployment-target.md](docs/adr/0002-ios-deployment-target.md)。
- 本地进度、记录和设置用 JSON 文件，见 [docs/adr/0001-local-storage.md](docs/adr/0001-local-storage.md)。P3 之前不要写存储实现。
