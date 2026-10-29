# 测试进度

新测试工程师从本文件和 [TEMPLATE.md](TEMPLATE.md) 继续。

## P0

- `Packages/SudokuEngine` 有占位类型的单元测试。
- `SudokuAppTests` 有首页文案的示例测试。
- 跨模块测试、图层测试、OCR 样本从后续阶段再加。样本目录是 `Tests/ocr-samples/`。
- 2026-10-29：引擎测试、SwiftLint、SwiftFormat 在 Linux 上通过。没有在 macOS 上执行 `xcodebuild`，App 构建和 App 测试留到 CI。详见 [2026-10-29-p0.md](2026-10-29-p0.md)。
