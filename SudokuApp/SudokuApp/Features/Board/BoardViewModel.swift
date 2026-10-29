import Observation

/// 唯一性检查最多数到 2：0 无解，1 唯一，2 表示至少还有另一个解。
private let solutionCountLimit = 2

/// 一次离线求解的结果。计数针对求解前的盘面，不是填满之后的那一盘。
private struct SolveOutcome: Sendable {
    let grid: Grid?
    let count: Int
}

/// 对求解前的盘面计数。不要把填满的结果再送进 `solutionCount`，否则多解题会变成 1。
private func makeSolveOutcome(
    engine: any SudokuBoardEngine,
    grid: Grid,
    rules: Rules
) -> SolveOutcome {
    let solved = engine.solve(grid, rules: rules)
    let count = engine.solutionCount(grid, rules: rules, limit: solutionCountLimit)
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
    private var countGeneration = 0
    private var countTask: Task<Void, Never>?

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
        let found = engine.conflicts(in: puzzle.givens, rules: puzzle.rules)
        conflicts = Self.linearSet(found, size: puzzle.rules.size)
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
            value != Grid.emptyCell && !givens.contains(index)
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
        guard let cell = cell(at: selectedIndex) else {
            return
        }
        guard !givens.contains(selectedIndex) else {
            notice = .givenLocked
            return
        }
        guard grid[cell] != value else {
            return
        }
        pushUndo()
        grid[cell] = value
        refreshConflicts()
        notice = .idle
        scheduleSolutionCount()
    }

    func clearSelected() {
        enter(Grid.emptyCell)
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
        scheduleSolutionCount()
    }

    func undo() {
        move(from: &undoStack, onto: &redoStack)
    }

    func redo() {
        move(from: &redoStack, onto: &undoStack)
    }

    /// 按当前盘面重新计数。旧请求作废，避免界面停在「正在查看」。
    func refreshSolutionCount() async {
        scheduleSolutionCount()
        await countTask?.value
    }

    /// 等最近一次后台计数结束。输入和撤销自己会发起计数，测试用这个收口。
    func finishSolutionCount() async {
        await countTask?.value
    }

    func autoSolve() async {
        guard beginSolve() else {
            return
        }
        countTask?.cancel()
        countGeneration += 1
        let generation = countGeneration
        let snapshot = grid
        let outcome = await fetchOutcome(for: snapshot)
        guard !Task.isCancelled, generation == countGeneration else {
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

    func state(at index: Int) -> BoardCellState {
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

    func accepts(_ value: Int) -> Bool {
        if value == Grid.emptyCell {
            return true
        }
        guard rules.size > 0 else {
            return false
        }
        return (1 ... rules.size).contains(value)
    }

    func cell(at index: Int) -> CellIndex? {
        guard rules.size > 0, grid.cells.indices.contains(index) else {
            return nil
        }
        return CellIndex(linearIndex: index, size: rules.size)
    }

    func clearedGrid() -> Grid {
        var next = grid
        for index in next.cells.indices where !givens.contains(index) {
            guard let cell = cell(at: index) else {
                continue
            }
            next[cell] = Grid.emptyCell
        }
        return next
    }

    func pushUndo() {
        undoStack.append(grid)
        redoStack.removeAll()
    }

    func move(from source: inout [Grid], onto destination: inout [Grid]) {
        guard !isSolving, let replacement = source.popLast() else {
            return
        }
        destination.append(grid)
        grid = replacement
        refreshConflicts()
        notice = .idle
        scheduleSolutionCount()
    }

    func refreshConflicts() {
        conflicts = Self.linearSet(engine.conflicts(in: grid, rules: rules), size: rules.size)
    }

    func scheduleSolutionCount() {
        countTask?.cancel()
        countGeneration += 1
        let generation = countGeneration
        let snapshot = grid
        let activeRules = rules
        countTask = Task {
            let count = await Self.countSolutions(engine: engine, grid: snapshot, rules: activeRules)
            guard !Task.isCancelled, generation == countGeneration else {
                return
            }
            solutionCount = count
        }
    }

    func beginSolve() -> Bool {
        guard !isSolving else {
            return false
        }
        isSolving = true
        notice = .idle
        return true
    }

    func fetchOutcome(for snapshot: Grid) async -> SolveOutcome {
        let activeRules = rules
        return await Task.detached { [engine] in
            makeSolveOutcome(engine: engine, grid: snapshot, rules: activeRules)
        }.value
    }

    func apply(_ outcome: SolveOutcome) {
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

    static func countSolutions(
        engine: any SudokuBoardEngine,
        grid: Grid,
        rules: Rules
    ) async -> Int {
        await Task.detached {
            engine.solutionCount(grid, rules: rules, limit: solutionCountLimit)
        }.value
    }

    static func linearSet(_ cells: Set<CellIndex>, size: Int) -> Set<Int> {
        var indexes: Set<Int> = []
        for cell in cells {
            indexes.insert(cell.linearIndex(size: size))
        }
        return indexes
    }

    static func givenIndexes(in grid: Grid) -> Set<Int> {
        var indexes: Set<Int> = []
        for (index, value) in grid.cells.enumerated() where value != Grid.emptyCell {
            indexes.insert(index)
        }
        return indexes
    }
}
