import SwiftUI

/// 数字键盘。位数跟着棋盘尺寸走，清除只作用于当前格。
struct NumberPadView: View {
    let size: Int
    let isEnabled: Bool
    /// 自动筛选禁用的数字，变灰且不能点。
    var disabledDigits: Set<Int> = []
    let onDigit: (Int) -> Void
    let onClear: () -> Void

    var body: some View {
        if size < 1 {
            EmptyView()
        } else {
            pad
        }
    }

    private var pad: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: digitColumns, spacing: 8) {
                ForEach(1 ... size, id: \.self) { digit in
                    Button(String(digit)) {
                        onDigit(digit)
                    }
                    .buttonStyle(PadButtonStyle())
                    .disabled(disabledDigits.contains(digit))
                    .accessibilityLabel("数字 \(digit)")
                }
            }
            Button(BoardCopy.clearCell, action: onClear)
                .buttonStyle(PadButtonStyle())
                .accessibilityHint(BoardCopy.clearCellHint)
        }
        .disabled(!isEnabled)
    }

    private var digitColumns: [GridItem] {
        let count = size > 5 ? 3 : size
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }
}

/// 键盘按钮。按下时加深底色，给一个明确的点按反馈。
private struct PadButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 44)
            // 禁用时只换颜色，不再叠加透明度（双重减淡对比度太低）
            .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
            .background(background(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 8))
    }

    private func background(isPressed: Bool) -> Color {
        Color.accentColor.opacity(isPressed ? 0.35 : 0.15)
    }
}
