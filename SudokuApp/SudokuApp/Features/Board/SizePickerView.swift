import SudokuEngine
import SwiftUI

/// 尺寸入口。选中后进入对应尺寸的内置题目。
struct SizePickerView: View {
    @State private var library = LibraryViewModel(bank: PuzzleBankStore().load())
    @State private var difficulty: Difficulty = .easy
    // 点击时选一次题，避免视图刷新时反复抽题、求解
    @State private var route: PlayRoute?
    @State private var isOpening = false
    // 用户题库文件读不出来或损坏时为 false：此时题库只有内置题，不能拿它清存档
    @State private var allowsOrphanCleanup = true
    // 长按「重新开始这一题」后等确认的那道题
    @State private var restartID: PuzzleFingerprint?
    // 预览里没有进度模型，当作空进度
    @Environment(PuzzleProgressModel.self) private var progressModel: PuzzleProgressModel?

    private var progress: HomeProgress {
        HomeProgress(entries: library.builtinEntries(difficulty: difficulty),
                     records: progressModel?.records ?? PuzzleProgressRecords(),
                     inProgressIDs: progressModel?.inProgressIDs ?? [],
                     restartableIDs: progressModel?.restartableIDs ?? [])
    }

    private var isAskingRestart: Binding<Bool> {
        Binding(get: { restartID != nil }, set: { if !$0 { restartID = nil } })
    }

    /// 刷新存档标记，并顺手清掉题已不存在的存档（只在回到首页时做，不在重绘里做）。
    private func refreshSessions() {
        let knownIDs = allowsOrphanCleanup ? HomeProgress.knownSessionIDs(bank: library.bank) : nil
        progressModel?.refreshSessionIndex(keeping: knownIDs)
    }

    /// 上次玩的题能接着玩时才有值（有存档、不是全解、题还在）。
    private var resumeTarget: ResumeTarget? {
        HomeProgress.resumeTarget(
            lastPlayed: progressModel?.lastPlayed,
            inProgressIDs: progressModel?.inProgressIDs ?? [],
            bank: library.bank
        )
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
                            .contextMenu {
                                if progress.restartableIDs.contains(fixtureSessionID(preset)) {
                                    Button(ProgressCopy.restartAction) { restartID = fixtureSessionID(preset) }
                                }
                            }
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
            .onAppear {
                reloadLibrary()
                refreshSessions() // 刚关掉的棋盘可能写了或删了存档
            }
            // 从棋盘退回首页时视图不一定重新出现，所以路由回到 nil 也要刷新
            .onChange(of: route) { _, newRoute in if newRoute == nil { refreshSessions() } }
            .confirmationDialog(
                ProgressCopy.restartAction, isPresented: isAskingRestart, titleVisibility: .visible,
                presenting: restartID // 用传进来的 id，免得关窗时 restartID 先被清空
            ) { id in
                Button(ProgressCopy.restartConfirm, role: .destructive) { progressModel?.restartPuzzle(id: id) }
                Button(ProgressCopy.restartCancel, role: .cancel) {}
            } message: { _ in
                Text(ProgressCopy.restartMessage)
            }
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
            lastPlayedText: HomeProgress.lastPlayedText(progressModel?.lastPlayed, bank: library.bank),
            onResume: resumeTarget.map { _ in resumeLastPlayed }
        )
        if current.total == 0 {
            Text(ProgressCopy.emptyDifficulty)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            PuzzleTileGrid(tiles: current.tiles, onSelect: { tile in open(.nine, entry: tile.entry) },
                           onRestart: { tile in restartID = tile.id })
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

    /// 回到上次玩的题；题库题会先把难度切过去，进棋盘时由存档恢复。
    private func resumeLastPlayed() {
        switch resumeTarget {
        case .fixture(let preset):
            open(preset)
        case .bank(let entry, let level):
            difficulty = level
            open(.nine, entry: entry)
        case nil:
            break
        }
    }

    /// 在所选难度的内置题里随机来一题；没有题就用内置示例题。
    private func openRandom() {
        var generator = SystemRandomNumberGenerator()
        open(.nine, entry: progress.randomEntry(using: &generator))
    }

    /// 重新读文件，让刚导入的题能被看到。
    private func reloadLibrary() {
        let result = PuzzleBankStore().loadResult()
        allowsOrphanCleanup = result.allowsOrphanCleanup
        library.reload(result.bank)
    }

    private func fixtureSessionID(_ preset: BoardPreset) -> PuzzleFingerprint {
        preset == .four ? HomeProgress.fixture4 : HomeProgress.fixture5
    }

    private func presetLabel(_ preset: BoardPreset) -> some View {
        let fixtureID = fixtureSessionID(preset)
        let isInProgress = progress.inProgressIDs.contains(fixtureID)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.title)
                    .font(.headline)
                Text(preset.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isInProgress {
                Text(ProgressCopy.inProgress).font(.caption).foregroundStyle(AppTheme.pineGreen)
            }
            if progress.isCompleted(fixtureID) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.pineGreen)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(preset.title)，\(preset.detail)"
                + ProgressCopy.stateSuffix(isCompleted: progress.isCompleted(fixtureID), isInProgress: isInProgress)
        )
    }
}

#Preview {
    SizePickerView()
}
