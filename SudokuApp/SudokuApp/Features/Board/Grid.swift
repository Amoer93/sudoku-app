/// 一行优先的棋盘。`cells` 长度是 `size * size`，`0`（`emptyCell`）是空格。
///
/// `cells` 只能读。写入走下标，避免把数组换成和边长不一致的内容。
/// 构造时就检查长度和取值，之后才交给引擎。
struct Grid: Codable, Equatable, Hashable, Sendable {
    enum ValidationError: Error, Equatable, Sendable {
        case unsupportedSize(Int)
        case cellCountMismatch(expected: Int, actual: Int)
        case invalidCellValue(Int, size: Int)
    }

    static let emptyCell = 0

    let size: Int
    private(set) var cells: [Int]

    init(rules: Rules) {
        size = rules.size
        cells = Array(repeating: Self.emptyCell, count: rules.cellCount)
    }

    init(size: Int, cells: [Int]) throws {
        try Self.validate(size: size, cells: cells)
        self.size = size
        self.cells = cells
    }

    subscript(row row: Int, column column: Int) -> Int {
        get {
            cells[offset(row: row, column: column)]
        }
        set {
            write(newValue, row: row, column: column)
        }
    }

    subscript(_ index: CellIndex) -> Int {
        get {
            self[row: index.row, column: index.column]
        }
        set {
            self[row: index.row, column: index.column] = newValue
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Int.self, forKey: .size)
        let cells = try container.decode([Int].self, forKey: .cells)
        try self.init(size: size, cells: cells)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(cells, forKey: .cells)
    }

    private enum CodingKeys: String, CodingKey {
        case size
        case cells
    }

    private func write(_ newValue: Int, row: Int, column: Int) {
        precondition(
            newValue >= Self.emptyCell && newValue <= size,
            "cell value must be 0...size"
        )
        cells[offset(row: row, column: column)] = newValue
    }

    private func offset(row: Int, column: Int) -> Int {
        precondition(row >= 0 && row < size, "row out of range")
        precondition(column >= 0 && column < size, "column out of range")
        return row * size + column
    }

    private static func validate(size: Int, cells: [Int]) throws {
        guard Rules.supportedSizes.contains(size) else {
            throw ValidationError.unsupportedSize(size)
        }
        let expected = size * size
        guard cells.count == expected else {
            throw ValidationError.cellCountMismatch(expected: expected, actual: cells.count)
        }
        if let invalid = cells.first(where: { $0 < emptyCell || $0 > size }) {
            throw ValidationError.invalidCellValue(invalid, size: size)
        }
    }
}
