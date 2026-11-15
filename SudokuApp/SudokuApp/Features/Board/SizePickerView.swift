import SudokuEngine
import SwiftUI

/// 首页：先选棋盘尺寸和难度，再点一道内置题开始。
struct SizePickerView: View {
    // 题库页用的题库：只有 9×9 内置题和导入题
    @State private var library = LibraryViewModel(bank: PuzzleBankStore().load())
    // 首页用的题库：再加上 4×4 / 5×5 的内置题
    @State private var homeBank = PuzzleBankStore().load().mergingSmallBuiltin()
    @State private var preset: BoardPreset = .nine
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
        HomeProgress(entries: homeBank.builtinEntries(difficulty: difficulty, size: preset.size),
                     records: progressModel?.records ?? PuzzleProgressRecords(),
                     inProgressIDs: progressModel?.inProgressIDs ?? [],
                     restartableIDs: progressModel?.restartableIDs ?? [])
    }

    private var isAskingRestart: Binding<Bool> {
        Binding(get: { restartID != nil }, set: { if !$0 { restartID = nil } })
    }

    /// 刷新存档标记，并顺手清掉题已不存在的存档（只在回到首页时做，不在重绘里做）。
    private func refreshSessions() {
        let knownIDs = allowsOrphanCleanup ? HomeProgress.knownSessionIDs(bank: homeBank) : nil
        progressModel?.refreshSessionIndex(keeping: knownIDs)
    }

    /// 当前尺寸、当前难度上次玩的那一条；别的尺寸和难度各记各的。
    private var gridLastPlayed: LastPlayedRecord? {
        progressModel?.records.lastPlayed(size: preset.size, difficulty: difficulty)
    }

    /// 切换棋盘尺寸；新尺寸没有当前难度时回到它有的档位。
    private func select(_ newPreset: BoardPreset) {
        preset = newPreset
        difficulty = newPreset.clamping(difficulty)
    }

    /// 这一条能接着玩时才有值（有存档、不是全解、题还在）。
    private func resumeTarget(for record: LastPlayedRecord?) -> ResumeTarget? {
        HomeProgress.resumeTarget(
            lastPlayed: record,
            inProgressIDs: progressModel?.inProgressIDs ?? [],
            bank: homeBank
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
                        ForEach(BoardPreset.allCases) { chip in boardChip(chip) }
                    }
                } header: {
                    Label(ProgressCopy.smallBoards, systemImage: "square.grid.3x3")
                }
                Section {
                    Picker(LibraryCopy.difficultyTitle, selection: $difficulty) {
                        ForEach(preset.difficulties, id: \.self) { level in Text(LibraryCopy.title(level)).tag(level) }
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
                PuzzleTileGrid(tiles: tiles, onSelect: { tile in open(tile.entry) },
                               onRestart: { tile in restartID = tile.id },
                               resumeLabel: resumeLabel(for: gridLastPlayed), onResume: onResume)
            }
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }

    /// 继续控件的朗读，例如「继续上一次，困难第 4 题」；说不出是哪道题时只读「继续上一次」。
    private func resumeLabel(for record: LastPlayedRecord?) -> String {
        let text = HomeProgress.lastPlayedText(record, bank: homeBank)
        if text == ProgressCopy.lastPlayedNone {
            return ProgressCopy.resume
        }
        return ProgressCopy.resumeVoiceOver(from: text)
    }

    /// 棋盘挑选里的一格：只负责切换尺寸。玩到一半、对勾和 ▶ 都在下面的题目格子上。
    private func boardChip(_ chip: BoardPreset) -> some View {
        let isSelected = chip == preset
        return Button { select(chip) } label: { chipLabel(chip, isSelected: isSelected) }
            .buttonStyle(.plain)
            .accessibilityLabel(chip.accessibilityTitle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// 点击时才求解（只做一次），放在后台做，完成后再跳转。棋盘尺寸跟着题走。
    private func open(_ entry: PuzzleBankEntry) {
        guard !isOpening else {
            return
        }
        isOpening = true
        Task {
            let puzzle = await LibraryViewModel.resolvePuzzle(for: entry)
            let boardPreset = BoardPreset.forSize(entry.size)
            if let newRoute = PlayRoute.making(preset: boardPreset, entry: entry, puzzle: puzzle) {
                route = newRoute
            }
            isOpening = false
        }
    }

    /// 回到上次玩的题；进棋盘时由存档恢复。首页只接着玩题库题，不再打开旧的固定题。
    private func resume(_ target: ResumeTarget) {
        if case .bank(let entry, _) = target {
            open(entry)
        }
    }

    /// 重新读文件，让刚导入的题能被看到。小棋盘题只并进首页这一份，题库页不要。
    private func reloadLibrary() {
        let result = PuzzleBankStore().loadResult()
        allowsOrphanCleanup = result.allowsOrphanCleanup
        library.reload(result.bank)
        homeBank = result.bank.mergingSmallBuiltin()
    }

    /// 一格的样子：只有标题；选中的用松绿色底。
    private func chipLabel(_ chip: BoardPreset, isSelected: Bool) -> some View {
        Text(chip.title)
            .font(.headline)
            .foregroundStyle(isSelected ? AppTheme.onButtonText : AppTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? AppTheme.pineGreen : AppTheme.raisedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle()) // 点文字旁边的空白也算点到这一格
    }
}

#Preview {
    SizePickerView()
}
