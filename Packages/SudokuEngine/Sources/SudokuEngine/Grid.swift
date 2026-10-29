/// 一行优先的棋盘。
///
/// `cells` 的长度是 `size * size`。`0`（`Grid.emptyCell`）表示空格，已填数字是 `1...size`。
/// 存储方式和 `docs/TECH_DESIGN.md` 一致：整数数组，空格是 `0`。
/// 请用下标写入，这样长度和取值范围不会被直接替换数组破坏。
/// 编码键：`size`、`cells`。
public struct Grid: Codable, Equatable, Hashable, Sendable {
    /// 构造或解码遇到非法棋盘时抛出。解码失败会再包一层 `DecodingError`。
    public enum ValidationError: Error, Equatable, Sendable {
        /// 边长不是 `Rules.supportedSizes` 里的 4、5 或 9。
        case unsupportedSize(Int)
        /// `cells` 的长度不是 `size * size`。
        case cellCountMismatch(expected: Int, actual: Int)
        /// 出现了空格和 `1...size` 以外的数字。
        case invalidCellValue(Int, size: Int)
    }

    /// 空格的存储值。已填数字从 1 到 `size`。
    public static let emptyCell = 0

    /// 棋盘边长。必须和一起使用的 `Rules.size` 相同。
    public let size: Int

    /// 行优先存储。下标 `row * size + column`。长度为 `size * size`。
    public private(set) var cells: [Int]

    /// 生成一张全空的棋盘，边长取自规则。
    public init(rules: Rules) {
        size = rules.size
        cells = Array(repeating: Self.emptyCell, count: rules.cellCount)
    }

    /// 用已有格子构造棋盘。长度必须是 `size * size`，每个值必须在 `0...size`。
    public init(size: Int, cells: [Int]) throws {
        try Self.validate(size: size, cells: cells)
        self.size = size
        self.cells = cells
    }

    /// 读取或写入一格。调用形式：`grid[row: 0, column: 1]`。
    ///
    /// 前置条件：行列都在 `0..<size`，新值在 `0...size`。否则触发 precondition。
    public subscript(row row: Int, column column: Int) -> Int {
        get {
            cells[offset(row: row, column: column)]
        }
        set {
            precondition(
                newValue >= Self.emptyCell && newValue <= size,
                "cell value must be 0...size"
            )
            cells[offset(row: row, column: column)] = newValue
        }
    }

    /// 用 `CellIndex` 读取或写入一格。调用形式：`grid[index]`。
    ///
    /// 前置条件与 `subscript(row:column:)` 相同。
    public subscript(_ index: CellIndex) -> Int {
        get {
            self[row: index.row, column: index.column]
        }
        set {
            self[row: index.row, column: index.column] = newValue
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Int.self, forKey: .size)
        let cells = try container.decode([Int].self, forKey: .cells)
        do {
            try self.init(size: size, cells: cells)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "grid does not match the supported shape",
                    underlyingError: error
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(cells, forKey: .cells)
    }

    private enum CodingKeys: String, CodingKey {
        case size
        case cells
    }

    private func offset(row: Int, column: Int) -> Int {
        precondition(row >= 0 && row < size, "row out of range")
        precondition(column >= 0 && column < size, "column out of range")
        return row * size + column
    }

    /// 先拒绝不支持的边长，再检查长度，最后检查每个格子的值。
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
