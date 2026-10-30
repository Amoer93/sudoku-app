import Observation

/// 唯一性检查最多数到 2：0 无解，1 唯一，2 表示至少还有另一个解。
private let solutionCountLimit = 2

/// 一次离线求解的结果。计数针对求解前的盘面，不是填满之后的那一盘。
private struct SolveOutcome: Sendable {
    let grid: Grid?
    let count: Int
}

/// 对求解前的当前盘面（给定数字 + 玩家填入）计数。不要把填满的结果再送进 `solutionCount`，否则多解题会变成 1。
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
    // 下面几个属性要被 BoardViewModel+Layers.swift 读写。Swift 没有跨文件的受限写权限，
    // 所以只能放宽到 internal（不加 private）；其余属性仍保持 private。
    var undoStack: [BoardSnapshot] = []
    var redoStack: [BoardSnapshot] = []
    var layers: [AssumptionLayer] = []
    /// 每格是在第几层填的，0 表示确定数字（含题目给定）。
    var cellDepths: [Int]
    private var countGeneration = 0
    private var countTask: Task<Void, Never>?

    /// 盘面一变，提示高亮就作废。回滚假设层时 Layers 扩展要写它，所以去掉了 private(set)。
    var grid: Grid {
        didSet {
            hintedIndex = nil
        }
    }

    /// 提示高亮的格子。用户选别的格、填数、撤销、清空、自动解题后都会清掉。
    private(set) var hintedIndex: Int?
    private(set) var selectedIndex: Int?
    /// 自动筛选模式。默认关闭，关闭时键盘行为和以前完全一样。
    var isAutoFilterOn = false
    private(set) var conflicts: Set<Int>
    private(set) var solutionCount: Int?
    /// 回滚假设层时 Layers 扩展要把它重置为 idle，所以去掉了 private(set)。
    var notice: BoardNotice = .idle
    private(set) var isSolving = false

    init(title: String, puzzle: SamplePuzzle, engine: any SudokuBoardEngine = EngineBoardAdapter()) {
        self.title = title
        rules = puzzle.rules
        self.engine = engine
        grid = puzzle.givens
        givens = Self.givenIndexes(in: puzzle.givens)
        cellDepths = Array(repeating: 0, count: puzzle.givens.cells.count)
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

    /// 自动筛选时要禁用的数字。
    /// 关闭、没选格、选中给定格（整块键盘本来就禁用）时都返回空集合。
    var disabledValues: Set<Int> {
        guard isAutoFilterOn, let selectedIndex, !givens.contains(selectedIndex),
              let cell = cell(at: selectedIndex)
        else {
            return []
        }
        return PeerValues.used(in: grid, rules: rules, at: cell)
    }

    /// 自动筛选下，选中的空格 1 到 N 全被禁用，说明前面可能填错了。
    var hasNoCandidates: Bool {
        guard isAutoFilterOn, let selectedIndex, !givens.contains(selectedIndex),
              grid.cells.indices.contains(selectedIndex),
              grid.cells[selectedIndex] == Grid.emptyCell,
              rules.size > 0
        else {
            return false
        }
        return disabledValues.isSuperset(of: Set(1 ... rules.size))
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
        if hasNoCandidates {
            return BoardCopy.noCandidates
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
        if notice == .idle, hasNoCandidates {
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

    /// 请求提示：选中并高亮确定格，只给位置，绝不填数字。
    /// 找不到确定格（含盘面已有冲突）时显示「当前无唯一解，请假设。」。
    func showHint() {
        guard !isSolving else {
            return
        }
        // 盘面有冲突时提示没有意义，先让玩家修正
        guard conflicts.isEmpty else {
            hintedIndex = nil
            notice = .hintBlockedByConflicts
            return
        }
        // 盘面已填满，没有可提示的格子，也不必说「无唯一解」
        guard grid.cells.contains(Grid.emptyCell) else {
            hintedIndex = nil
            notice = .solved
            return
        }
        guard let cell = engine.hintCell(in: grid, rules: rules) else {
            showAssumption()
            return
        }
        let index = cell.linearIndex(size: rules.size)
        guard grid.cells.indices.contains(index) else {
            return
        }
        selectedIndex = index
        hintedIndex = index
        notice = .hinted
    }

    func select(index: Int) {
        guard !isSolving, grid.cells.indices.contains(index) else {
            return
        }
        hintedIndex = nil
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
        // 被筛掉的数字不写入，和键盘上变灰保持一致
        guard !disabledValues.contains(value) else {
            return
        }
        let before = grid
        pushUndo()
        grid[cell] = value
        retagDepths(since: before)
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
        let before = grid
        pushUndo()
        grid = next
        retagDepths(since: before)
        clearAllLayers()
        refreshConflicts()
        notice = .cleared
        scheduleSolutionCount()
    }

    func undo() {
        move(from: &undoStack, onto: &redoStack)
        dropLayersBeyondUndo()
    }

    func redo() {
        move(from: &redoStack, onto: &undoStack)
    }

    /// 按当前盘面重新计数。旧请求作废，避免界面停在「正在查看」。
    /// 自动解题进行中直接跳过：递增 `countGeneration` 会让求解结果被当成过期而丢掉。
    func refreshSolutionCount() async {
        guard !isSolving else {
            return
        }
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
    /// 没有确定格时改为推荐一个假设格；只选中并高亮，不改盘面。
    func showAssumption() {
        guard let assumption = engine.assumptionCell(in: grid, rules: rules) else {
            hintedIndex = nil
            notice = .noHint
            return
        }
        // 先检查行列范围，因为 linearIndex 越界会直接崩溃
        let cell = assumption.cell
        let size = rules.size
        guard (0 ..< size).contains(cell.row), (0 ..< size).contains(cell.column) else {
            hintedIndex = nil
            notice = .noHint
            return
        }
        // 行列都在范围内，线性下标必然落在盘面内
        let index = cell.linearIndex(size: size)
        selectedIndex = index
        hintedIndex = index
        notice = .assumption(assumption.candidates)
    }

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
            isConflict: conflicts.contains(index),
            isHinted: hintedIndex == index,
            layerDepth: layerDepth(at: index),
            isAssumptionHint: hintedIndex == index && isHintAnAssumption
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
        undoStack.append(snapshot())
        redoStack.removeAll()
    }

    func move(from source: inout [BoardSnapshot], onto destination: inout [BoardSnapshot]) {
        guard !isSolving, let replacement = source.popLast() else {
            return
        }
        destination.append(snapshot())
        grid = replacement.grid
        cellDepths = replacement.depths
        clampDepthsToLayers()
        refreshConflicts()
        notice = .idle
        scheduleSolutionCount()
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
            let before = grid
            pushUndo()
            grid = solved
            retagDepths(since: before)
            refreshConflicts()
        }
        clearAllLayers()
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
}

/// 这两个方法要被 BoardViewModel+Layers.swift 调用，所以不能放在 private 扩展里。
extension BoardViewModel {
    func refreshConflicts() {
        conflicts = Self.linearSet(engine.conflicts(in: grid, rules: rules), size: rules.size)
    }

    func scheduleSolutionCount() {
        // 求解中不发起计数，求解结束时 `apply` 会写入求解前盘面的解个数。
        guard !isSolving else {
            return
        }
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
}
