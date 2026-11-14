import SwiftUI

/// 色板里的颜色，具体色值都放在 AppTheme 里。
enum AssumptionLayerColor: Hashable {
    case ink
    case clay
    case plum
    case moss
    case berry

    var swiftUIColor: Color {
        switch self {
        case .ink:
            return AppTheme.layerInk
        case .clay:
            return AppTheme.layerClay
        case .plum:
            return AppTheme.layerPlum
        case .moss:
            return AppTheme.layerMoss
        case .berry:
            return AppTheme.layerBerry
        }
    }
}

/// 一层假设的外观。纯数据，方便测试。
struct AssumptionLayerStyle: Equatable {
    let name: AssumptionLayerColor
    let opacity: Double

    /// 每层颜色各不相同，数字只略微调透明，保证浅色和深色下都看得清（对比度不低于 3:1）；
    /// 超过色板长度后循环。
    private static let palette: [AssumptionLayerStyle] = [
        AssumptionLayerStyle(name: .ink, opacity: 0.9),
        AssumptionLayerStyle(name: .clay, opacity: 0.85),
        AssumptionLayerStyle(name: .plum, opacity: 0.8),
        AssumptionLayerStyle(name: .moss, opacity: 0.9),
        AssumptionLayerStyle(name: .berry, opacity: 0.85)
    ]

    /// 第 `depth` 层的样式。0 层（确定数字）返回 nil，沿用原来的颜色。
    static func style(forDepth depth: Int) -> AssumptionLayerStyle? {
        guard depth > 0 else {
            return nil
        }
        return palette[(depth - 1) % palette.count]
    }

    /// 蒙版底色的固定透明度。深色模式下也够淡，不会盖住数字。
    static let tintOpacity = 0.15

    /// 第 `depth` 层的底色：和数字同一个色相，只是更淡。0 层没有底色。
    static func tintColor(forDepth depth: Int) -> Color? {
        guard let style = style(forDepth: depth) else {
            return nil
        }
        return style.name.swiftUIColor.opacity(tintOpacity)
    }

    var color: Color {
        name.swiftUIColor.opacity(opacity)
    }
}
