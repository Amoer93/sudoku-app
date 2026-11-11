import SwiftUI
import UIKit

/// 「校园划线」视觉：颜色、字号、线宽都从这里取，不在别处写死。
enum AppTheme {
    // MARK: - 颜色（浅色 / 深色，不用资源文件，跟随系统外观）

    static let pageBackground = dynamic(light: 0xE4EBED, dark: 0x12181B)
    static let raisedSurface = dynamic(light: 0xF7FBFC, dark: 0x1C2428)
    static let boardCell = dynamic(light: 0xFCFDFD, dark: 0x171E22)
    static let primaryText = dynamic(light: 0x1A2428, dark: 0xE8EEF0)
    static let secondaryText = dynamic(light: 0x4A5C63, dark: 0xA3B3B8)
    /// 格线（细）。带透明度，所以单独写。
    static let thinLine = dynamic(
        light: UIColor(red: 26 / 255, green: 36 / 255, blue: 40 / 255, alpha: 0.18),
        dark: UIColor(red: 232 / 255, green: 238 / 255, blue: 240 / 255, alpha: 0.16)
    )
    /// 宫线和外框同色。
    static let boxLine = dynamic(light: 0x2A3A40, dark: 0xC5D0D4)
    /// 主色：松绿。
    static let pineGreen = dynamic(light: 0x1B6B5C, dark: 0x5DCFB5)
    /// 松绿浅底：选中格、可用数字键。
    static let pineFill = dynamic(light: 0xD4EBE4, dark: 0x1E3D38)
    /// 行列宫高亮底色。
    static let peerHighlight = dynamic(light: 0xCFDCE1, dark: 0x2A3840)
    /// 同数字高亮底色（只定义，功能还没做）。
    static let sameDigit = dynamic(light: 0xC5E4DB, dark: 0x1E3D38)
    /// 冲突底色；冲突格的字仍用 primaryText。
    static let conflictBackground = dynamic(light: 0xF8D4D1, dark: 0x4A2220)
    static let hintGoldText = dynamic(light: 0x7A6410, dark: 0xE8C85A)
    static let hintGoldBackground = dynamic(light: 0xF7E9B5, dark: 0x3D3414)
    /// 主按钮上的字色。
    static let onButtonText = dynamic(light: 0xF7FBFC, dark: 0x12181B)

    // MARK: - 字号和尺寸

    /// 题目给出的数字：粗体。
    static let givenDigitSize: CGFloat = 22
    static let givenDigitWeight: Font.Weight = .bold
    /// 玩家填的数字：半粗体，略小，和题目数字分开。
    static let userDigitSize: CGFloat = 20
    static let userDigitWeight: Font.Weight = .semibold

    /// 线宽（点）。外框比宫线略粗，格线最细。
    static let hairlineWidth: Double = 0.5
    static let boxLineWidth: Double = 2
    static let frameLineWidth: Double = 2.5
    /// 选中格内侧描边宽度。
    static let selectedStrokeWidth: CGFloat = 2
    static let boardCornerRadius: CGFloat = 8

    // MARK: - 私有工具

    /// 用十六进制数造一个随外观切换的颜色。
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        return dynamic(light: uiColor(hex: light), dark: uiColor(hex: dark))
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        let provider = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return dark
            }
            return light
        }
        return Color(uiColor: provider)
    }

    private static func uiColor(hex: UInt32) -> UIColor {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
