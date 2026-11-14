import SwiftUI

/// 进度卡片：进度条、做完几道、累计、上次玩的。
struct ProgressCardView: View {
    let progress: HomeProgress
    let lastPlayedText: String
    /// 为空表示没有能继续的棋盘，此时不显示按钮。
    var onResume: (() -> Void)?

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
            Text(lastPlayedText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let onResume {
                Button(action: onResume) {
                    Label(ProgressCopy.resume, systemImage: "play.fill")
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.pineGreen)
                .accessibilityHint(ProgressCopy.resumeHint)
            }
        }
        .padding(.vertical, 4)
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

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tiles) { tile in
                Button { onSelect(tile) } label: { cell(tile) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ProgressCopy.tileVoiceOver(
                        number: tile.number, isCompleted: tile.isCompleted, isInProgress: tile.isInProgress
                    ))
                    .contextMenu {
                        if tile.isRestartable, let onRestart {
                            Button(ProgressCopy.restartAction) { onRestart(tile) }
                        }
                    }
            }
        }
        .padding(.vertical, 4)
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
