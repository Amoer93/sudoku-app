import SwiftUI

/// 一层假设的外观。纯数据，方便测试。
struct AssumptionLayerStyle: Equatable {
    /// 色板里的颜色名，和 `color` 一一对应。
    let name: String
    let opacity: Double

    /// 透明度逐层降低，颜色各不相同；超过色板长度后循环。
    private static let palette: [AssumptionLayerStyle] = [
        AssumptionLayerStyle(name: "blue", opacity: 0.85),
        AssumptionLayerStyle(name: "orange", opacity: 0.7),
        AssumptionLayerStyle(name: "green", opacity: 0.55),
        AssumptionLayerStyle(name: "purple", opacity: 0.85),
        AssumptionLayerStyle(name: "pink", opacity: 0.7)
    ]

    /// 第 `depth` 层的样式。0 层（确定数字）返回 nil，沿用原来的颜色。
    static func style(forDepth depth: Int) -> AssumptionLayerStyle? {
        guard depth > 0 else {
            return nil
        }
        return palette[(depth - 1) % palette.count]
    }

    var color: Color {
        let base: Color
        switch name {
        case "blue":
            base = .blue
        case "orange":
            base = .orange
        case "green":
            base = .green
        case "purple":
            base = .purple
        default:
            base = .pink
        }
        return base.opacity(opacity)
    }
}
