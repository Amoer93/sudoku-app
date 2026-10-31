# BoardVision

拍照识别从 P4 开始。照片只在设备端处理，不上传。

## PR A：纯逻辑层

输入已校正的方图和边长（4/5/9），输出 `RecognitionResult`。不依赖 App 的 `Grid`，由 App 再转换。

- `CellSlicer`：切成 n×n 小图，每边裁掉约 8% 去掉格线。
- `InkDetector`：墨迹比例 < 2% 判为空格，不调 Vision。
- `CellTextRecognizer`：识别协议；`VisionCellTextRecognizer` 是真实实现，测试用假实现。
- `BoardRecognizer`：只收 `1...n` 的单个数字；置信度 ≥0.8 可信，0.5..<0.8 低置信度，其余待确认。

外框检测和透视校正在 PR B。
