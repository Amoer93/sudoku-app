import SwiftUI

/// 小的「继续上一次」控件：图标小，但点按区域至少 44×44。
struct ResumeButton: View {
    let voiceOverLabel: String
    var symbol = "play.circle.fill"
    var symbolFont: Font = .title2
    /// 图标在点按区域里靠哪边；格子上靠左上角，免得盖住数字。
    var alignment: Alignment = .center
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(symbolFont)
                .foregroundStyle(AppTheme.pineGreen)
                .padding(4)
                .frame(minWidth: 44, minHeight: 44, alignment: alignment)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voiceOverLabel)
        .accessibilityHint(ProgressCopy.resumeHint)
    }
}

extension View {
    /// 长按出现「重新开始这一题」；没有动作时不加菜单。
    @ViewBuilder
    func restartContextMenu(action: (() -> Void)?) -> some View {
        if let action {
            contextMenu {
                Button(ProgressCopy.restartAction) { action() }
            }
        } else {
            self
        }
    }
}

/// 进度卡片：进度条、做完几道、累计。「上次玩的」由格子和棋盘挑选上的 ▶ 表示。
struct ProgressCardView: View {
    let progress: HomeProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress.fraction)
                .tint(AppTheme.pineGreen)
                .accessibilityHidden(true)
            Text(progress.summaryText)
                .font(.headline)
                .accessibilityLabel(voiceOverText)
            if progress.totalCompletions > 0 {
                Text(ProgressCopy.cumulative(progress.totalCompletions))
                    .font(.subheadline)
            }
        }
    }

    /// 没做完时读完整数字；0 道和全做完用原句。
    private var voiceOverText: String {
        if progress.doneCount == 0 || (progress.total > 0 && progress.doneCount == progress.total) {
            return progress.summaryText
        }
        return ProgressCopy.progressVoiceOver(done: progress.doneCount, total: progress.total)
    }
}

/// 题目编号格子：点一格就开那道题。
struct PuzzleTileGrid: View {
    let tiles: [HomeProgress.Tile]
    let onSelect: (HomeProgress.Tile) -> Void
    /// 长按菜单「重新开始这一题」；只有带存档的格子才显示。
    var onRestart: ((HomeProgress.Tile) -> Void)?
    var resumeLabel = ProgressCopy.resume
    /// 有值时，只在「上次玩的、还玩到一半」的那一格上放继续控件。
    var onResume: (() -> Void)?

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tiles) { tile in
                // 两个按钮是兄弟，不互相嵌套；各挂同一个长按菜单，外层的菜单到不了叠在上面的按钮
                let restart = restartAction(for: tile)
                ZStack(alignment: .topLeading) {
                    Button { onSelect(tile) } label: { cell(tile) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ProgressCopy.tileVoiceOver(
                            number: tile.number, isCompleted: tile.isCompleted, isInProgress: tile.isInProgress
                        ))
                        .restartContextMenu(action: restart)
                    if let onResume, tile.isLastPlayed, tile.isInProgress {
                        ResumeButton(voiceOverLabel: resumeLabel, symbol: "play.fill", symbolFont: .caption2,
                                     alignment: .topLeading, action: onResume)
                            .restartContextMenu(action: restart)
                    }
                }
            }
        }
    }

    /// 这一格的「重新开始」动作；没有存档就没有。
    private func restartAction(for tile: HomeProgress.Tile) -> (() -> Void)? {
        guard tile.isRestartable, let onRestart else {
            return nil
        }
        return { onRestart(tile) }
    }

    private func cell(_ tile: HomeProgress.Tile) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Text("\(tile.number)").font(.headline)
                if tile.isInProgress {
                    Text(ProgressCopy.inProgress)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(AppTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(tile.isCompleted ? AppTheme.pineFill : AppTheme.raisedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.pineGreen, lineWidth: tile.isLastPlayed ? 2 : 0)
            }
            if tile.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.pineGreen)
                    .padding(2)
            }
        }
    }
}
