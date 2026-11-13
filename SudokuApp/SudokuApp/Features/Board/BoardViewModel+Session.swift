import Foundation
import SudokuEngine

/// 存档快照：把当前棋盘拍成可编码的数据，再从数据恢复。这里不读写文件。
extension BoardViewModel {
    /// 拍一张当前盘面的快照，只读，不改任何状态。
    /// 层数超过 9 时一个字符放不下，返回 nil（实际玩不到这么深，只是不让它崩）。
    func makeSessionState(puzzleID: PuzzleFingerprint, savedAt: Date) -> BoardSessionState? {
        let all = [snapshot()] + layers.map(\.snapshot) + undoStack + redoStack
        let deepest = all.flatMap(\.depths).max() ?? 0
        guard deepest <= BoardSessionState.maxEncodedDepth else {
            return nil
        }
        let current = Self.encode(snapshot())
        return BoardSessionState(
            puzzleID: puzzleID,
            savedAt: savedAt,
            size: rules.size,
            usedAutoSolve: usedAutoSolve,
            hasRecordedCompletion: hasRecordedCompletion,
            grid: current.grid,
            depths: current.depths,
            layers: layers.map { layer in
                let text = Self.encode(layer.snapshot)
                return SessionLayer(grid: text.grid, depths: text.depths, undoCount: layer.undoCount)
            },
            undoStack: undoStack.map(Self.encode),
            redoStack: redoStack.map(Self.encode)
        )
    }

    /// 先校验再恢复：存档对不上这道题就返回 nil。
    /// 选中格、提示、提示文案、自动筛选这些临时状态不恢复，保持初始值。
    /// 恢复时仍不调用 onPlayerCompleted / updatePlayerCompletion()；
    /// 「做完」补记由 BoardSessionLauncher.backfillCompletion 在恢复成功后做。
    static func restored(
        title: String,
        puzzle: SamplePuzzle,
        session: BoardSessionState,
        puzzleID: PuzzleFingerprint,
        engine: any SudokuBoardEngine = EngineBoardAdapter()
    ) -> BoardViewModel? {
        guard let valid = session.validated(against: puzzle, puzzleID: puzzleID),
              let current = decode(valid, valid.grid, valid.depths)
        else {
            return nil
        }
        var restoredLayers: [AssumptionLayer] = []
        for layer in valid.layers {
            guard let item = decode(valid, layer.grid, layer.depths) else {
                return nil
            }
            restoredLayers.append(AssumptionLayer(snapshot: item, undoCount: layer.undoCount))
        }
        let undoList = valid.undoStack.compactMap { decode(valid, $0.grid, $0.depths) }
        let redoList = valid.redoStack.compactMap { decode(valid, $0.grid, $0.depths) }
        guard undoList.count == valid.undoStack.count, redoList.count == valid.redoStack.count else {
            return nil
        }
        let model = BoardViewModel(title: title, puzzle: puzzle, engine: engine)
        model.grid = current.grid
        model.cellDepths = current.depths
        model.layers = restoredLayers
        model.undoStack = undoList
        model.redoStack = redoList
        model.usedAutoSolve = valid.usedAutoSolve
        model.hasRecordedCompletion = valid.hasRecordedCompletion
        model.refreshConflicts()
        model.scheduleSolutionCount()
        return model
    }

    private static func encode(_ snapshot: BoardSnapshot) -> SessionSnapshot {
        SessionSnapshot(
            grid: BoardSessionState.encode(cells: snapshot.grid.cells),
            depths: BoardSessionState.encode(cells: snapshot.depths)
        )
    }

    /// 输入已经校验过；万一 Grid 还是构造失败，就返回 nil 让整次恢复作废。
    private static func decode(_ state: BoardSessionState, _ gridText: String, _ depthText: String) -> BoardSnapshot? {
        guard let pair = state.decodePair(gridText, depthText),
              let grid = try? Grid(size: state.size, cells: pair.grid)
        else {
            return nil
        }
        return BoardSnapshot(grid: grid, depths: pair.depths)
    }
}
