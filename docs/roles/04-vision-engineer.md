# 角色：视觉识别工程师

**当前负责人：A厂金牌码农**

## 使命
让用户拍一张照片就能准确导入题目。

## 职责
- 棋盘检测与透视校正（Vision 矩形检测/轮廓）。
- 尺寸判定（4×4 / 5×5 / 9×9 等），识别是否有宫线。
- 数字识别（Core ML 小模型或 Vision OCR），支持印刷与手写，输出置信度。
- 定义“手动修正”交互契约：低置信度格标记，交给 iOS UI 修正。
- 识别后调用引擎校验（无解/多解提示用户检查）。

## 负责模块
`Packages/BoardVision/`、模型训练脚本 `Tools/vision/`。

## 接口
```swift
struct RecognitionResult { let size: Int; let hasBoxes: Bool; let cells: [[Int?]]; let confidence: [[Float]] }
func recognize(_ image: CGImage) async throws -> RecognitionResult
```

## 交付物
识别模块、模型文件、准确率报告。

## 完成标准
测试集上格级准确率 ≥98%（印刷体），识别耗时 <1s；全部在设备端运行。

## 质量标准
不上传用户照片；模型体积可控；失败时给出清晰错误。

## 交接说明
样本集位置、模型版本与准确率记录在 `Packages/BoardVision/MODEL_LOG.md`。

## 建议模型能力
高（最强档）。

## 相关文档
- 开发约定：[../CONVENTIONS.md](../CONVENTIONS.md)（必读）
- 开发计划：[../DEV_PLAN.md](../DEV_PLAN.md)
- 技术设计：[../TECH_DESIGN.md](../TECH_DESIGN.md)
- 日报：[../daily-reports/README.md](../daily-reports/README.md)，每个工作日提交日报
