import SudokuEngine
import SwiftUI

/// 尺寸入口。选中后进入对应尺寸的内置题目。
struct SizePickerView: View {
    @State private var library = LibraryViewModel(bank: PuzzleBankStore().load())
    @State private var difficulty: Difficulty = .easy
    // 点击时选一次题，避免视图刷新时反复抽题、求解
    @State private var route: PlayRoute?
    @State private var isOpening = false
    // 预览里没有进度模型，当作空进度
    @Environment(PuzzleProgressModel.self) private var progressModel: PuzzleProgressModel?

    private var progress: HomeProgress {
        HomeProgress(entries: library.builtinEntries(difficulty: difficulty),
                     records: progressModel?.records ?? PuzzleProgressRecords())
    }

    var body: some View {
        NavigationStack {
            List {
                Text(HomeCopy.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowSeparator(.hidden)
                Picker(LibraryCopy.difficultyTitle, selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in Text(LibraryCopy.title(level)).tag(level) }
                }
                .pickerStyle(.segmented)
                // 分段控件放不下副标题，所以选中专家时在下面显示一行
                if let subtitle = TrialTagCopy.pickerSubtitle(for: difficulty) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(subtitle)
                }
                progressSection
                Section(ProgressCopy.smallBoards) {
                    ForEach([BoardPreset.four, .five]) { preset in
                        Button { open(preset) } label: { presetLabel(preset) }
                            .buttonStyle(.plain)
                    }
                }
                Button(action: openRandom) {
                    Label(ProgressCopy.random, systemImage: "shuffle").font(.headline)
                }
                .buttonStyle(.plain)
                NavigationLink(LibraryCopy.entry) {
                    LibraryView(model: library).onAppear(perform: reloadLibrary)
                }
                NavigationLink(PhotoImportCopy.entry) {
                    PhotoImportView()
                }
            }
            .navigationTitle(HomeCopy.title)
            .onAppear(perform: reloadLibrary)
            .navigationDestination(item: $route) { route in
                // 每次点击一个新 id：换题时重建 BoardScreen，模型跟着刷新
                BoardScreen(preset: route.preset, puzzle: route.puzzle, bankEntry: route.entry).id(route.id)
            }
        }
    }

    /// 进度卡片和题目格子；这一档没题时给一句提示。
    @ViewBuilder private var progressSection: some View {
        let current = progress
        ProgressCardView(
            progress: current,
            lastPlayedText: HomeProgress.lastPlayedText(progressModel?.lastPlayed, bank: library.bank)
        )
        if current.total == 0 {
            Text(ProgressCopy.emptyDifficulty)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            PuzzleTileGrid(tiles: current.tiles) { tile in open(.nine, entry: tile.entry) }
        }
    }

    /// 点击时才选题（只选一次）；9×9 的求解在后台做，完成后再跳转。
    private func open(_ preset: BoardPreset, entry: PuzzleBankEntry? = nil) {
        guard !isOpening else {
            return
        }
        isOpening = true
        Task {
            var puzzle: SamplePuzzle?
            if let entry {
                puzzle = await LibraryViewModel.resolvePuzzle(for: entry)
            }
            if let newRoute = PlayRoute.making(preset: preset, entry: entry, puzzle: puzzle) {
                route = newRoute
            }
            isOpening = false
        }
    }

    /// 在所选难度的内置题里随机来一题；没有题就用内置示例题。
    private func openRandom() {
        var generator = SystemRandomNumberGenerator()
        open(.nine, entry: progress.randomEntry(using: &generator))
    }

    /// 重新读文件，让刚导入的题能被看到。
    private func reloadLibrary() {
        library.reload(PuzzleBankStore().load())
    }

    private func presetLabel(_ preset: BoardPreset) -> some View {
        let fixtureID = preset == .four ? HomeProgress.fixture4 : HomeProgress.fixture5
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title)
                    .font(.headline)
                Text(preset.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if progress.isCompleted(fixtureID) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.pineGreen)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.title)，\(preset.detail)" + (progress.isCompleted(fixtureID) ? "，已经做完" : ""))
    }
}

#Preview {
    SizePickerView()
}
