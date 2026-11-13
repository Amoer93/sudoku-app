import Foundation
import SudokuEngine

/// 一步撤销/重做记录的存档形式：盘面和每格层数都写成数字串。
struct SessionSnapshot: Codable, Equatable {
    var grid: String
    var depths: String
}

/// 一层假设的存档形式：开层前的盘面，加上开层时撤销栈的长度。
struct SessionLayer: Codable, Equatable {
    var grid: String
    var depths: String
    var undoCount: Int
}

/// 一局棋的存档快照（v1）。只管编码和校验，不碰磁盘。
/// 盘面用数字串存：长度是 size * size，每个字符一个数字。
/// 层数一个字符放不下 10 以上，所以 v1 的 depths 只支持 0...9。
struct BoardSessionState: Codable, Equatable {
    /// 当前能读懂的格式版本。更新的版本一律当作没有存档，不做迁移。
    static let currentSchemaVersion = 1
    /// 数字串里单个层数的上限（一个字符）。
    static let maxEncodedDepth = 9

    var schemaVersion = BoardSessionState.currentSchemaVersion
    var puzzleID: PuzzleFingerprint
    var savedAt: Date
    var size: Int
    var usedAutoSolve = false
    var hasRecordedCompletion = false
    var grid: String
    var depths: String
    var layers: [SessionLayer] = []
    var undoStack: [SessionSnapshot] = []
    var redoStack: [SessionSnapshot] = []
}

// MARK: - JSON

extension BoardSessionState {
    /// 必填项缺了就抛错（等于没有存档）；其余字段缺了用默认值，方便以后加字段。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        puzzleID = try container.decode(PuzzleFingerprint.self, forKey: .puzzleID)
        size = try container.decode(Int.self, forKey: .size)
        grid = try container.decode(String.self, forKey: .grid)
        depths = try container.decode(String.self, forKey: .depths)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date(timeIntervalSince1970: 0)
        usedAutoSolve = try container.decodeIfPresent(Bool.self, forKey: .usedAutoSolve) ?? false
        hasRecordedCompletion = try container.decodeIfPresent(Bool.self, forKey: .hasRecordedCompletion) ?? false
        layers = try container.decodeIfPresent([SessionLayer].self, forKey: .layers) ?? []
        undoStack = try container.decodeIfPresent([SessionSnapshot].self, forKey: .undoStack) ?? []
        redoStack = try container.decodeIfPresent([SessionSnapshot].self, forKey: .redoStack) ?? []
    }

    /// 存和读都用这一套设置，和 PuzzleProgressRecords 一样用毫秒时间戳。
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    /// 解码失败返回 nil（当作没有存档），不抛给调用方。
    static func decode(from data: Data) -> BoardSessionState? {
        try? makeDecoder().decode(BoardSessionState.self, from: data)
    }

    func encoded() -> Data? {
        try? Self.makeEncoder().encode(self)
    }
}

// MARK: - 数字串

extension BoardSessionState {
    static func encode(cells: [Int]) -> String {
        cells.map { String($0) }.joined()
    }

    /// 只认 ASCII 数字（全角数字也拒绝）；长度必须是 count，每位不能超过 maxValue。
    static func decodeCells(_ text: String, count: Int, maxValue: Int) -> [Int]? {
        var cells: [Int] = []
        for byte in text.utf8 {
            guard byte >= 48, byte <= 57, Int(byte) - 48 <= maxValue else {
                return nil
            }
            cells.append(Int(byte) - 48)
        }
        return cells.count == count ? cells : nil
    }

    /// 一对盘面和层数的数字串，按本存档的 size 解开；只查长度和取值范围。
    func decodePair(_ gridText: String, _ depthText: String) -> (grid: [Int], depths: [Int])? {
        let count = size * size
        guard let cells = Self.decodeCells(gridText, count: count, maxValue: size),
              let depthValues = Self.decodeCells(depthText, count: count, maxValue: Self.maxEncodedDepth)
        else {
            return nil
        }
        return (cells, depthValues)
    }
}

// MARK: - 校验

extension BoardSessionState {
    /// 对照要恢复的题检查存档；任何一项不对都返回 nil，绝不崩溃。
    /// 题目给定的数字必须原样保留，这样存档放错题或题被改过都会被挡住。
    func validated(against puzzle: SamplePuzzle) -> BoardSessionState? {
        guard schemaVersion == Self.currentSchemaVersion, size == puzzle.rules.size,
              puzzle.givens.cells.count == size * size
        else {
            return nil
        }
        // 当前盘面和各层快照的层数不能超过现有层数；撤销/重做里的可能更深（重做会带回来），只限 0...9
        var pairs: [(grid: String, depths: String, maxDepth: Int)] = [(grid, depths, layers.count)]
        pairs += layers.map { ($0.grid, $0.depths, layers.count) }
        pairs += (undoStack + redoStack).map { ($0.grid, $0.depths, Self.maxEncodedDepth) }
        for item in pairs {
            guard let decoded = decodePair(item.grid, item.depths),
                  decoded.depths.allSatisfy({ $0 <= item.maxDepth }),
                  keepsGivens(decoded.grid, of: puzzle)
            else {
                return nil
            }
        }
        return hasValidUndoCounts ? self : nil
    }

    private func keepsGivens(_ cells: [Int], of puzzle: SamplePuzzle) -> Bool {
        for (index, given) in puzzle.givens.cells.enumerated() where given != Grid.emptyCell {
            if cells[index] != given {
                return false
            }
        }
        return true
    }

    /// undoCount 不能超过撤销栈长度，且从外层到内层不能变小。
    private var hasValidUndoCounts: Bool {
        var previous = 0
        for layer in layers {
            guard layer.undoCount >= previous, layer.undoCount <= undoStack.count else {
                return false
            }
            previous = layer.undoCount
        }
        return true
    }
}
