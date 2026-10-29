import Observation

/// 一次离线求解的结果。放在类型外面，耗时调用就不待在主线程方法里。
private struct SolveOutcome: Sendable {
    let grid: Grid?
    let count: Int
}

/// 替身和以后的真引擎都从这里调用。不要在视图模型里写搜索。
private func makeSolveOutcome(
    engine: any SudokuBoardEngine,
    grid: Grid,
    rules: Rules
) -> SolveOutcome {
    let solved = engine.solve(grid, rules: rules)
    let counted = solved ?? grid
    let count = engine.solutionCount(counted, rules: rules)
    return SolveOutcome(grid: solved, count: count)
}

/// 棋盘状态。撤销栈和选中格在这里，规则判断交给引擎。
@MainActor
@Observable
final class BoardViewModel {
    let title: String
    let rules: Rules

    private let engine: any SudokuBoardEngine
    private let givens: Set<Int>
    private var undoStack: [Grid] = []
    private var redoStack: [Grid] = []

    private(set) var grid: Grid
    private(set) var selectedIndex: Int?
    private(set) var conflicts: Set<Int>
    private(set) var solutionCount: Int?
    private(set) var notice: BoardNotice = .idle
    private(set) var isSolving = false

    init(title: String, puzzle: SamplePuzzle, engine: any SudokuBoardEngine = FixtureBoardEngine()) {
        self.title = title
        rules = puzzle.rules
        self.engine = engine
        grid = puzzle.givens
        givens = Self.givenIndexes(in: puzzle.givens)
        conflicts = engine.conflicts(in: puzzle.givens, rules: puzzle.rules)
    }

    var cellStates: [BoardCellState] {
        grid.cells.indices.map { index in
            state(at: index)
        }
    }

    var canUndo: Bool {
        !undoStack.isEmpty && !isSolving
    }

    var canRedo: Bool {
        !redoStack.isEmpty && !isSolving
    }

    var canClear: Bool {
        !isSolving && grid.cells.enumerated().contains { index, value in
            value != 0 && !givens.contains(index)
        }
    }

    var canEnter: Bool {
        guard !isSolving, let selectedIndex else {
            return false
        }
        return !givens.contains(selectedIndex)
    }

    var statusText: String {
        if isSolving {
            return BoardCopy.solving
        }
        if let text = notice.text {
            return text
        }
        return selectionHint
    }

    var statusIsWarning: Bool {
        if isSolving {
            return false
        }
        if notice.isWarning {
            return true
        }
        guard notice == .idle, let selectedIndex else {
            return false
        }
        return givens.contains(selectedIndex)
    }

    var solutionCountText: String {
        guard let solutionCount else {
            return BoardCopy.checkingSolutions
        }
        switch solutionCount {
        case 0:
            return BoardCopy.noSolution
        case 1:
            return BoardCopy.uniqueSolution
        default:
            return BoardCopy.multipleSolutions
        }
    }

    var solutionCountIsWarning: Bool {
        solutionCount == 0
    }

    func select(index: Int) {
        guard !isSolving, grid.cells.indices.contains(index) else {
            return
        }
        if selectedIndex == index {
            selectedIndex = nil
        } else {
            selectedIndex = index
        }
        notice = .idle
    }

    func enter(_ value: Int) {
        guard !isSolving, let selectedIndex, accepts(value) else {
            return
        }
        guard grid.cells.indices.contains(selectedIndex) else {
            return
        }
        guard !givens.contains(selectedIndex) else {
            notice = .givenLocked
            return
        }
        guard grid.cells[selectedIndex] != value else {
            return
        }
        pushUndo()
        grid.cells[selectedIndex] = value
        refreshConflicts()
        notice = .idle
    }

    func clearSelected() {
        enter(0)
    }

    func clearUserEntries() {
        guard !isSolving else {
            return
        }
        let next = clearedGrid()
        guard next != grid else {
            return
        }
        pushUndo()
        grid = next
        refreshConflicts()
        notice = .cleared
    }

    func undo() {
        move(from: &undoStack, onto: &redoStack)
    }

    func redo() {
        move(from: &redoStack, onto: &undoStack)
    }

    func loadSolutionCount() async {
        let snapshot = grid
        let activeRules = rules
        let count = await Task.detached { [engine] in
            engine.solutionCount(snapshot, rules: activeRules)
        }.value
        guard snapshot == grid, !Task.isCancelled else {
            return
        }
        solutionCount = count
    }

    func autoSolve() async {
        guard beginSolve() else {
            return
        }
        let outcome = await fetchOutcome()
        guard !Task.isCancelled else {
            isSolving = false
            return
        }
        apply(outcome)
    }
}

/// 格子、撤销和求解的具体步骤。拆出来是为了让主类型保持短小。
private extension BoardViewModel {
    var selectionHint: String {
        guard let selectedIndex else {
            return BoardCopy.selectCell
        }
        if givens.contains(selectedIndex) {
            return BoardCopy.givenLocked
        }
        return BoardCopy.enterDigit
    }

    private func state(at index: Int) -> BoardCellState {
        let size = max(rules.size, 1)
        return BoardCellState(
            index: index,
            row: index / size,
            column: index % size,
            value: grid.cells[index],
            isGiven: givens.contains(index),
            isSelected: selectedIndex == index,
            isConflict: conflicts.contains(index)
        )
    }

    private func accepts(_ value: Int) -> Bool {
        if value == 0 {
            return true
        }
        guard rules.size > 0 else {
            return false
        }
        return (1...rules.size).contains(value)
    }

    private func clearedGrid() -> Grid {
        var next = grid
        for index in next.cells.indices where !givens.contains(index) {
            next.cells[index] = 0
        }
        return next
    }

    private func pushUndo() {
        undoStack.append(grid)
        redoStack.removeAll()
    }

    private func move(from source: inout [Grid], onto destination: inout [Grid]) {
        guard !isSolving, let replacement = source.popLast() else {
            return
        }
        destination.append(grid)
        grid = replacement
        refreshConflicts()
        notice = .idle
    }

    private func refreshConflicts() {
        conflicts = engine.conflicts(in: grid, rules: rules)
    }

    private func beginSolve() -> Bool {
        guard !isSolving else {
            return false
        }
        isSolving = true
        notice = .idle
        return true
    }

    private func fetchOutcome() async -> SolveOutcome {
        let snapshot = grid
        let activeRules = rules
        return await Task.detached { [engine] in
            makeSolveOutcome(engine: engine, grid: snapshot, rules: activeRules)
        }.value
    }

    private func apply(_ outcome: SolveOutcome) {
        isSolving = false
        solutionCount = outcome.count
        guard let solved = outcome.grid else {
            notice = .unsolvable
            return
        }
        if solved != grid {
            pushUndo()
            grid = solved
            refreshConflicts()
        }
        notice = .solved
    }

    private static func givenIndexes(in grid: Grid) -> Set<Int> {
        var indexes: Set<Int> = []
        for (index, value) in grid.cells.enumerated() where value != 0 {
            indexes.insert(index)
        }
        return indexes
    }
}
