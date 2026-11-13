import Observation

/// 棋盘状态。撤销栈和选中格在这里，规则判断交给引擎。
@MainActor
@Observable
final class BoardViewModel {
    let title: String
    let rules: Rules

    // 放宽到 internal 只读：拆出去的扩展文件要读它；只有 init 会写。
    let engine: any SudokuBoardEngine
    // 放宽到 internal 只读：拆出去的扩展文件（状态文案、格子状态）要读它；只有 init 会写。
    let givens: Set<Int>
    // 下面这些存储属性放宽到 internal 可写：BoardViewModel+Steps.swift 里的步骤要写它们。
    var undoStack: [BoardSnapshot] = []
    var redoStack: [BoardSnapshot] = []
    var layers: [AssumptionLayer] = []
    /// 每格是在第几层填的，0 表示确定数字（含题目给定）。写入在本文件和 BoardViewModel+Steps.swift 里。
    var cellDepths: [Int]
    private var countGeneration = 0
    private var countTask: Task<Void, Never>?

    /// 盘面一变，提示高亮就作废。
    var grid: Grid {
        didSet {
            hintedIndex = nil
        }
    }

    /// 提示高亮的格子。用户选别的格、填数、撤销、清空、自动解题后都会清掉。
    var hintedIndex: Int?
    var selectedIndex: Int?
    /// 自动筛选模式。默认关闭，关闭时键盘行为和以前完全一样。
    var isAutoFilterOn = false
    private(set) var conflicts: Set<Int>
    var solutionCount: Int?
    var notice: BoardNotice = .idle
    var isSolving = false
    /// 用过「全解」：盘面是程序填的，不算玩家自己做完。清空后才重新算。
    var usedAutoSolve = false
    /// 这一局已记过「做完」：只有清空或新开一局才清掉，撤销重做不动它。
    var hasRecordedCompletion = false
    /// 玩家做完时通知外面记录；每局最多一次。
    @ObservationIgnored var onPlayerCompleted: (() -> Void)?

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

    /// 请求提示：选中并高亮确定格，只给位置，绝不填数字。
    /// 找不到确定格（含盘面已有冲突）时显示「当前无唯一解，可点「试一试」尝试。」。
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
        // 引擎给出的确定格必在盘面内，线性下标无需再检查
        let index = cell.linearIndex(size: rules.size)
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
        updatePlayerCompletion()
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
        usedAutoSolve = false
        hasRecordedCompletion = false
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

/// 假设层的写入逻辑。refreshConflicts 要写 conflicts（private(set)），scheduleSolutionCount 要用私有的计数状态，所以留在这里。
extension BoardViewModel {
    /// 开一层新假设，可以嵌套。
    func startLayer() {
        guard canStartLayer else {
            return
        }
        layers.append(AssumptionLayer(snapshot: snapshot(), undoCount: undoStack.count))
    }

    /// 撤回最上面一层：本层改过的格子全部回到开层前的值，本层的撤销记录一并丢掉。
    func rollbackLayer() {
        guard !isSolving, let layer = layers.popLast() else {
            return
        }
        grid = layer.snapshot.grid
        cellDepths = layer.snapshot.depths
        if undoStack.count > layer.undoCount {
            undoStack.removeSubrange(layer.undoCount...)
        }
        // 重做栈里的盘面可能含本层内容，留着会把已撤回的数字带回来
        redoStack.removeAll()
        refreshConflicts()
        notice = .idle
        updatePlayerCompletion()
        scheduleSolutionCount()
    }

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
