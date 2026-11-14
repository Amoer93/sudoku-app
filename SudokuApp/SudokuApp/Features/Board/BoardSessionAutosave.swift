import SudokuEngine
import SwiftUI

extension BoardViewModel {
    /// 和存档有关的盘面快照；变了就该存。
    var sessionToken: [Int] { grid.cells + [layers.count, undoStack.count, redoStack.count] }
}

extension BoardScreen {
    /// 没有稳定身份的题（如拍照导入）为空。
    var progressIdentity: ProgressPuzzleIdentity? {
        ProgressPuzzleIdentity(bankEntry: bankEntry, preset: preset, isCustomPuzzle: puzzle != nil)
    }
}

/// 一局棋的自动存档：改动后稍等再写，离开时立刻写，做完或清空时删掉。
@MainActor
final class BoardSessionAutosave {
    static let debounceDelay: Duration = .milliseconds(500)

    private let store: BoardSessionStore
    private let puzzleID: PuzzleFingerprint
    private weak var model: BoardViewModel? // 弱引用，避免和模型互相拿着
    private var pendingSave: Task<Void, Never>?
    private var hasUnsavedChanges = false
    /// 清空那一刻的盘面，不能再被写回；盘面一变就失效。
    private var ignoredToken: [Int]?

    init(store: BoardSessionStore, puzzleID: PuzzleFingerprint, model: BoardViewModel) {
        self.store = store
        self.puzzleID = puzzleID
        self.model = model
    }

    /// 盘面变了：记一笔，稍后写盘。
    func noteChange() {
        guard let model, model.sessionToken != ignoredToken else { return }
        ignoredToken = nil
        hasUnsavedChanges = true
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.debounceDelay)
            if !Task.isCancelled { self?.writeIfNeeded() }
        }
    }

    /// 马上写盘；没有新改动就不写。
    func flush() {
        pendingSave?.cancel()
        writeIfNeeded()
    }

    /// 删存档；先取消待写的保存，免得它又写回来。
    func clear() {
        pendingSave?.cancel()
        hasUnsavedChanges = false
        ignoredToken = model?.sessionToken
        store.remove(puzzleID: puzzleID)
    }

    private func writeIfNeeded() {
        guard hasUnsavedChanges, let state = model?.makeSessionState(puzzleID: puzzleID, savedAt: .now) else { return }
        hasUnsavedChanges = false
        store.save(state)
    }
}

/// 进入棋盘时决定是恢复存档还是新开一局。
@MainActor
enum BoardSessionLauncher {
    /// autosave 为空表示不存档；lostNotice 是存档读不回来时的提示。
    typealias Launch = (model: BoardViewModel, autosave: BoardSessionAutosave?, lostNotice: ImportNotice?)

    static func start(
        title: String,
        puzzle: SamplePuzzle,
        identity: ProgressPuzzleIdentity?,
        progress: PuzzleProgressModel?,
        engine: any SudokuBoardEngine
    ) -> Launch {
        var model = BoardViewModel(title: title, puzzle: puzzle, engine: engine)
        guard let identity, let progress else { return (model, nil, nil) }
        let sessions = progress.sessions
        var lostNotice: ImportNotice?
        switch sessions.loadResult(puzzleID: identity.id, puzzle: puzzle) {
        case .loaded(let session):
            if let restored = BoardViewModel.restored(
                title: title, puzzle: puzzle, session: session, puzzleID: identity.id, engine: engine
            ) {
                model = restored
                backfillCompletion(of: model, id: identity.id, progress: progress)
            } else {
                sessions.moveAside(puzzleID: identity.id) // 解出来但盘面用不了：挪开，下次不再提示
                lostNotice = ImportNotice(text: ProgressCopy.sessionLost, existingEntry: nil)
            }
        case .unreadable:
            lostNotice = ImportNotice(text: ProgressCopy.sessionLost, existingEntry: nil)
        case .none, .newerVersion:
            break // 没存过，或存档来自更新版本：静默新开一局，文件不动
        }
        return (model, BoardSessionAutosave(store: sessions, puzzleID: identity.id, model: model), lostNotice)
    }

    /// 恢复出的盘面若是玩家自己做完的：补记一次（已记过不加），再删存档；全解的不算。
    static func backfillCompletion(of model: BoardViewModel, id: PuzzleFingerprint, progress: PuzzleProgressModel) {
        guard model.isPlayerCompleted else { return }
        if !model.hasRecordedCompletion {
            model.hasRecordedCompletion = true
            progress.markCompleted(id: id)
        }
        progress.sessions.remove(puzzleID: id)
    }
}

private struct BoardAutosaveModifier: ViewModifier {
    let autosave: BoardSessionAutosave?
    let model: BoardViewModel
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: model.sessionToken) { autosave?.noteChange() }
            // App 切到后台或不在前台时立刻写盘，不能只等 onDisappear
            .onChange(of: scenePhase) { _, phase in if phase != .active { autosave?.flush() } }
            .onDisappear { autosave?.flush() }
    }
}

extension View {
    /// 给棋盘页接上自动存档；autosave 为空时什么都不做。
    func autosaving(_ autosave: BoardSessionAutosave?, model: BoardViewModel) -> some View {
        modifier(BoardAutosaveModifier(autosave: autosave, model: model))
    }
}
