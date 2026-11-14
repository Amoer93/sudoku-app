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

/// 进度卡片：上次玩的（需要时才有）、进度条、做完几道、累计。
struct ProgressCardView: View {
    /// 「上次玩的」那一行怎么显示。题已经在这页上时，由格子或小棋盘行负责，这里不重复。
    enum LastPlayedLine: Equatable {
        case hidden
        case plain(String) // 还不能继续：只是一行浅色字
        case resume(String) // 能继续，但题不在这页上：整行可点
    }

    let progress: HomeProgress
    var lastPlayed: LastPlayedLine = .hidden
    var resumeLabel = ProgressCopy.resume
    var onResume: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            lastPlayedRow
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

    /// 放在进度条上面：下面的摘要要紧挨着格子，不能被这一行挤开。
    @ViewBuilder private var lastPlayedRow: some View {
        switch lastPlayed {
        case .hidden:
            EmptyView()
        case .plain(let text):
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .resume(let text):
            if let onResume {
                Button(action: onResume) {
                    HStack(spacing: 8) {
                        Text(text).font(.subheadline)
                        Spacer(minLength: 8)
                        Image(systemName: "play.circle.fill").font(.title2)
                    }
                    .foregroundStyle(AppTheme.pineGreen)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(resumeLabel)
                .accessibilityHint(ProgressCopy.resumeHint)
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
                // 两个按钮是兄弟，不互相嵌套；长按菜单挂在外层，按在哪个上面都能出来
                ZStack(alignment: .topLeading) {
                    Button { onSelect(tile) } label: { cell(tile) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(ProgressCopy.tileVoiceOver(
                            number: tile.number, isCompleted: tile.isCompleted, isInProgress: tile.isInProgress
                        ))
                    if let onResume, tile.isLastPlayed, tile.isInProgress {
                        ResumeButton(voiceOverLabel: resumeLabel, symbol: "play.fill", symbolFont: .caption2,
                                     alignment: .topLeading, action: onResume)
                    }
                }
                .contextMenu {
                    if tile.isRestartable, let onRestart {
                        Button(ProgressCopy.restartAction) { onRestart(tile) }
                    }
                }
            }
        }
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
