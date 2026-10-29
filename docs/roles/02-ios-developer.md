# 角色：iOS 开发工程师

**当前负责人：A厂金牌码农**

## 使命
用 Swift/SwiftUI 构建流畅、易用、可上架的 App 本体。

## 职责
- 棋盘界面：4×4 / 5×5 / 9×9 渲染，根据规则显示/隐藏宫线，候选数笔记、输入、高亮冲突。
- **图层系统**：每次假设新建一个半透明图层，支持多层嵌套叠加，当前层高亮、下层逐级变淡；按层撤销、放弃、确认合并到下层。
- 提示交互：展示确定格提示及技巧说明；展示“最佳假设格”并一键进入假设图层。
- 计步与计时（步数口径与后端统一），排行榜界面、个人最佳记录。
- 拍照入口与识别结果修正界面（与视觉识别模块对接）。
- 题库浏览、下载、离线缓存。
- App Store 打包、签名、隐私清单、截图、描述、审核说明。

## 负责模块
`SudokuApp/`（Features/Board、Layers、Hints、Leaderboard、Camera UI）、App 配置与资源。

## 接口
- 调用 `SudokuEngine`：`solve`、`nextHint`、`bestAssumptionCell`、`validate`。
- 调用 `BoardVision`：`recognize(image) -> RecognitionResult`（尺寸、数字、置信度）。
- 调用后端 API：题库、提交成绩、排行榜。
- 不在 App 内复制算法逻辑，全部通过引擎接口。

## 交付物
可运行的 App、UI 组件、TestFlight 版本、上架材料。

## 完成标准
功能符合任务卡；UI 测试通过；iPhone 小屏/大屏、深色模式、动态字体下显示正常；无主线程卡顿。

## 质量标准
SwiftUI + MVVM；视图无业务逻辑；SwiftLint 零警告；无强制解包崩溃点；支持无障碍标签。

## 交接说明
图层状态模型见 `Features/Layers/README.md`（需维护）；记录未完成 UI 与已知问题；上架材料放 `SudokuApp/AppStore/`。

## 建议模型能力
中高，性价比模型即可。

## 相关文档
- 开发约定：[../CONVENTIONS.md](../CONVENTIONS.md)（必读）
- 开发计划：[../DEV_PLAN.md](../DEV_PLAN.md)
- 技术设计：[../TECH_DESIGN.md](../TECH_DESIGN.md)
- 日报：[../daily-reports/README.md](../daily-reports/README.md)，每个工作日提交日报
