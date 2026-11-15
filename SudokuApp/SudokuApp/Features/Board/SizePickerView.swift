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

    /// 当前难度上次玩的那一条；别的难度各记各的。
    private var gridLastPlayed: LastPlayedRecord? {
        progressModel?.records.lastPlayedByDifficulty[difficulty]
    }

    /// 4×4 / 5×5 固定题上次玩的那一条。
    private var fixtureLastPlayed: LastPlayedRecord? {
        progressModel?.records.lastPlayedFixture
    }

    /// 这一条能接着玩时才有值（有存档、不是全解、题还在）。
    private func resumeTarget(for record: LastPlayedRecord?) -> ResumeTarget? {
        HomeProgress.resumeTarget(
            lastPlayed: record,
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
                Section {
                    HStack(spacing: 8) {
                        ForEach(BoardPreset.allCases) { preset in boardChip(preset) }
                    }
                } header: {
                    Label(ProgressCopy.smallBoards, systemImage: "square.grid.3x3")
                }
                Section {
                    Picker(LibraryCopy.difficultyTitle, selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { level in Text(LibraryCopy.title(level)).tag(level) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden) // 难度、进度、格子是一块，中间不要细线
                    progressSection
                }
                Section(ProgressCopy.moreFeatures) {
                    NavigationLink(LibraryCopy.entry) {
                        LibraryView(model: library).onAppear(perform: reloadLibrary)
                    }
                    NavigationLink(PhotoImportCopy.entry) {
                        PhotoImportView()
                    }
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

    /// 进度卡片和题目格子放在同一行里，中间就不会有分隔线。
    /// 这一档没题时，卡片的摘要已经是「这一档还没有题目…」，不再重复写一遍。
    private var progressSection: some View {
        let current = progress
        let tiles = current.tiles
        var onResume: (() -> Void)?
        if let target = resumeTarget(for: gridLastPlayed) {
            onResume = { resume(target) }
        }
        return VStack(alignment: .leading, spacing: 12) {
            ProgressCardView(progress: current)
            if current.total > 0 {
                PuzzleTileGrid(tiles: tiles, onSelect: { tile in open(.nine, entry: tile.entry) },
                               onRestart: { tile in restartID = tile.id },
                               resumeLabel: resumeLabel(for: gridLastPlayed), onResume: onResume)
            }
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }

    /// 继续控件的朗读，例如「继续上一次，困难第 4 题」；说不出是哪道题时只读「继续上一次」。
    private func resumeLabel(for record: LastPlayedRecord?) -> String {
        let text = HomeProgress.lastPlayedText(record, bank: library.bank)
        if text == ProgressCopy.lastPlayedNone {
            return ProgressCopy.resume
        }
        return ProgressCopy.resumeVoiceOver(from: text)
    }

    /// 棋盘挑选里的一格。4×4 / 5×5 一点就开那道固定题；9×9 只表示「下面是九宫的题」，不另开题。
    /// 开题按钮和继续控件是兄弟，不互相嵌套；两个按钮各挂同一个长按菜单。
    @ViewBuilder
    private func boardChip(_ preset: BoardPreset) -> some View {
        if preset == .nine {
            // 小棋盘一点就进棋盘，不会停在选中态，所以首页选中的一直是 9×9；点它不用做任何事
            Button {} label: { chipLabel(preset, isSelected: true) }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.title)
                .accessibilityAddTraits(.isSelected)
        } else {
            let sessionID = fixtureSessionID(preset)
            let restart = fixtureRestartAction(sessionID)
            ZStack(alignment: .topLeading) {
                Button { open(preset) } label: { chipLabel(preset, isSelected: false) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.title + ProgressCopy.stateSuffix(
                        isCompleted: progress.isCompleted(sessionID),
                        isInProgress: progress.inProgressIDs.contains(sessionID)
                    ))
                    .restartContextMenu(action: restart)
                if fixtureLastPlayed?.id == sessionID, let target = resumeTarget(for: fixtureLastPlayed) {
                    ResumeButton(voiceOverLabel: resumeLabel(for: fixtureLastPlayed), symbol: "play.fill",
                                 symbolFont: .caption2, alignment: .topLeading) { resume(target) }
                        .restartContextMenu(action: restart)
                }
            }
        }
    }

    /// 固定题的「重新开始」动作；没有存档就没有。
    private func fixtureRestartAction(_ sessionID: PuzzleFingerprint) -> (() -> Void)? {
        guard progress.restartableIDs.contains(sessionID) else {
            return nil
        }
        return { restartID = sessionID }
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

    /// 回到上次玩的题；进棋盘时由存档恢复。题库题就在当前难度的格子上，不用再切难度。
    private func resume(_ target: ResumeTarget) {
        switch target {
        case .fixture(let preset):
            open(preset)
        case .bank(let entry, _):
            open(.nine, entry: entry)
        }
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

    /// 一格的样子：只有标题；选中（9×9）用松绿色底，小棋盘带「玩到一半」和对勾。
    private func chipLabel(_ preset: BoardPreset, isSelected: Bool) -> some View {
        let fixtureID = fixtureSessionID(preset)
        let isFixture = preset != .nine
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Text(preset.title).font(.headline)
                if isFixture, progress.inProgressIDs.contains(fixtureID) {
                    Text(ProgressCopy.inProgress).font(.caption2).lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(isSelected ? AppTheme.onButtonText : AppTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? AppTheme.pineGreen : AppTheme.raisedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if isFixture, progress.isCompleted(fixtureID) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.pineGreen)
                    .padding(2)
            }
        }
        .contentShape(Rectangle()) // 点文字旁边的空白也算点到这一格
    }
}

#Preview {
    SizePickerView()
}
