import SwiftUI

/// 撤销、重做、清空。图标配短标题，小屏上也能点到。
struct LayerCapsuleButton: View {
    let title: String
    let systemImage: String
    let hint: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}

struct BoardActionButton: View {
    let title: String
    let systemImage: String
    let hint: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}

/// 主按钮：松绿底、浅色字。只用在棋盘页的「全解」。
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.onButtonText)
            .background(AppTheme.pineGreen, in: RoundedRectangle(cornerRadius: 8))
            // 按下或不可用时只降透明度一次，不发光
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.5)
    }
}

/// 次按钮：松绿字、安静的浅底，按下时换成松绿浅底。
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? AppTheme.pineGreen : AppTheme.secondaryText)
            .background(
                configuration.isPressed ? AppTheme.pineFill : AppTheme.raisedSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
    }
}
