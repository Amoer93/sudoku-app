import BoardVision
import CoreGraphics
import Observation

/// 拍照导入的状态：识别结果、可编辑的格子、冲突和解的情况。不依赖界面，方便测试。
@MainActor
@Observable
final class PhotoImportViewModel {
    enum SolutionStatus: Equatable {
        case unique
        case multiple
        case noSolution
        case unknown
    }

    private(set) var preset: BoardPreset
    private(set) var result: RecognitionResult?
    private(set) var grid: Grid
    private(set) var reviewIndexes: Set<Int> = []
    private(set) var conflicts: Set<Int> = []
    private(set) var solutionStatus: SolutionStatus = .unknown
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    var selectedIndex: Int?

    @ObservationIgnored private let engine: any SudokuBoardEngine
    @ObservationIgnored private var correctedImage: CGImage?
    @ObservationIgnored private let detect: @Sendable (CGImage) throws -> CGImage
    @ObservationIgnored private let recognize: @Sendable (CGImage, Int) throws -> RecognitionResult
    @ObservationIgnored private var requestToken = 0 // 新请求加一，丢弃旧结果

    init(
        engine: any SudokuBoardEngine = EngineBoardAdapter(),
        detect: @escaping @Sendable (CGImage) throws -> CGImage = { try BoardDetector.detectAndCorrect($0) },
        recognize: @escaping @Sendable (CGImage, Int) throws -> RecognitionResult
            = { try PhotoImportViewModel.recognize($0, size: $1) }
    ) {
        let guessed = Self.guessPreset()
        self.engine = engine
        self.detect = detect
        self.recognize = recognize
        preset = guessed
        grid = Grid(rules: guessed.rules)
    }

    /// 占位：先默认 9×9，以后可以根据照片猜尺寸。
    static func guessPreset() -> BoardPreset {
        .nine
    }

    /// 冲突或解的情况对应的提示，按显示顺序排列。
    var messages: [String] {
        var texts: [String] = []
        if !conflicts.isEmpty {
            texts.append(PhotoImportCopy.conflicts)
        }
        if solutionStatus == .multiple {
            texts.append(PhotoImportCopy.multipleSolutions)
        }
        if solutionStatus == .noSolution {
            texts.append(PhotoImportCopy.noSolution)
        }
        return texts
    }

    /// 找棋盘并识别。重活放到后台线程，不卡界面。
    func load(image: CGImage) async {
        requestToken += 1
        let token = requestToken
        isLoading = true
        errorMessage = nil
        let size = preset.rules.size
        let detect = detect
        let recognize = recognize
        do {
            let output = try await Task.detached {
                let corrected = try detect(image)
                let recognized = try recognize(corrected, size)
                return (corrected, recognized)
            }.value
            guard token == requestToken else { return } // 旧请求的结果丢掉
            if apply(result: output.1) {
                correctedImage = output.0
            }
        } catch {
            guard token == requestToken else { return }
            fail(with: error)
        }
        isLoading = false
    }

    /// 换尺寸后用缓存的校正图重新识别；还没有图就只改尺寸。
    func changeSize(_ newPreset: BoardPreset) async {
        requestToken += 1
        let token = requestToken
        guard let image = correctedImage else {
            preset = newPreset
            grid = Grid(rules: newPreset.rules)
            isLoading = false
            refreshChecks()
            return
        }
        isLoading = true
        errorMessage = nil
        let size = newPreset.rules.size
        let recognize = recognize
        do {
            let recognized = try await Task.detached {
                try recognize(image, size)
            }.value
            guard token == requestToken else { return }
            apply(result: recognized)
        } catch {
            guard token == requestToken else { return }
            fail(with: error)
        }
        isLoading = false
    }

    /// 用识别结果覆盖当前格子和待确认集合。
    @discardableResult
    func apply(result newResult: RecognitionResult) -> Bool {
        let newGrid: Grid
        do {
            newGrid = try RecognitionGridAdapter.makeGrid(newResult)
        } catch {
            errorMessage = PhotoImportCopy.recognitionFailed
            return false
        }
        if let matched = BoardPreset.allCases.first(where: { $0.rules.size == newResult.size }) {
            preset = matched
        }
        grid = newGrid // 建盘成功后才改状态
        result = newResult
        reviewIndexes = RecognitionGridAdapter.reviewIndexes(newResult)
        selectedIndex = nil
        refreshChecks()
        return true
    }

    /// 给选中的格子填数字；用户改过的格子不用再复核。
    func setDigit(_ digit: Int) {
        guard digit >= 1, digit <= grid.size else {
            return
        }
        write(digit)
    }

    /// 清空选中的格子。
    func clear() {
        write(Grid.emptyCell)
    }

    /// 生成可以开局的题目。有冲突也照常导入。
    func makePuzzle() -> SamplePuzzle {
        let rules = preset.rules
        // 无解时没有答案，退回当前盘面占位
        let solution = engine.solve(grid, rules: rules) ?? grid
        return SamplePuzzle(rules: rules, givens: grid, solution: solution)
    }

    nonisolated static func recognize(_ image: CGImage, size: Int) throws -> RecognitionResult {
        let recognizer = BoardRecognizer(recognizer: VisionCellTextRecognizer())
        return try recognizer.recognize(squareImage: image, size: size)
    }

    private func write(_ value: Int) {
        guard let index = selectedIndex, index >= 0, index < grid.cells.count else {
            return
        }
        grid[CellIndex(linearIndex: index, size: grid.size)] = value
        reviewIndexes.remove(index)
        refreshChecks()
    }

    private func fail(with error: Error) {
        if let visionError = error as? BoardVisionError, visionError == .boardNotFound {
            errorMessage = PhotoImportCopy.boardNotFound
        } else {
            errorMessage = PhotoImportCopy.recognitionFailed
        }
    }

    private func refreshChecks() {
        let rules = preset.rules
        let found = engine.conflicts(in: grid, rules: rules)
        conflicts = Set(found.map { $0.linearIndex(size: grid.size) })
        if !conflicts.isEmpty {
            // 已有冲突时必然无解，不再多算，只提示冲突
            solutionStatus = .unknown
            return
        }
        switch engine.solutionCount(grid, rules: rules, limit: 2) {
        case 0:
            solutionStatus = .noSolution
        case 1:
            solutionStatus = .unique
        default:
            solutionStatus = .multiple
        }
    }
}
