/// 数独规则。P1 只接受三种标准规格，宫约束不能单独改写。
///
/// - 4×4：宫为 2×2
/// - 5×5：拉丁方，只有行和列，没有宫
/// - 9×9：宫为 3×3
///
/// `boxRows` 和 `boxCols` 是一个宫内部的行数和列数，不是棋盘上宫的个数。
/// 例如 9×9 里第 `row` 行属于第 `row / boxRows` 条横带。
/// 当前不接受 6×6；编码键已经按技术设计留好，以后只放宽校验，不改键名。
/// 编码键：`size`、`boxRows`、`boxCols`。5×5 的宫字段编码为 null。
public struct Rules: Codable, Equatable, Hashable, Sendable {
    /// 构造或解码遇到非法规则时抛出。解码失败会再包一层 `DecodingError`。
    public enum ValidationError: Error, Equatable, Sendable {
        /// 边长不是 4、5 或 9。
        case unsupportedSize(Int)
        /// 宫尺寸和边长不匹配。4 必须是 2×2，9 必须是 3×3，5 必须没有宫。
        case invalidBoxDimensions(size: Int, boxRows: Int?, boxCols: Int?)
    }

    /// P1 支持的边长，顺序固定为 4、5、9。
    public static let supportedSizes: [Int] = [4, 5, 9]

    /// 4×4，宫 2×2。
    public static let fourByFour = Rules(validatedSize: 4, boxRows: 2, boxCols: 2)

    /// 5×5 拉丁方，没有宫。
    public static let fiveByFive = Rules(validatedSize: 5, boxRows: nil, boxCols: nil)

    /// 9×9，宫 3×3。
    public static let nineByNine = Rules(validatedSize: 9, boxRows: 3, boxCols: 3)

    /// 棋盘边长。
    public let size: Int

    /// 一个宫里有几行。与 `boxCols` 同时为 nil 表示没有宫约束。
    public let boxRows: Int?

    /// 一个宫里有几列。与 `boxRows` 同时为 nil 表示没有宫约束。
    public let boxCols: Int?

    /// 是否启用宫约束。4×4 和 9×9 为 true，5×5 为 false。
    public var hasBoxes: Bool {
        boxRows != nil && boxCols != nil
    }

    /// 格子总数，等于 `size * size`。
    public var cellCount: Int {
        size * size
    }

    /// 按标准规格构造规则。非法组合抛出 `ValidationError`，不会生成半合法值。
    ///
    /// - Parameters:
    ///   - size: 必须是 4、5 或 9。
    ///   - boxRows: 宫内行数。5×5 必须为 nil，4×4 必须为 2，9×9 必须为 3。
    ///   - boxCols: 宫内列数，必须和 `boxRows` 成对出现。
    public init(size: Int, boxRows: Int?, boxCols: Int?) throws {
        try Self.validate(size: size, boxRows: boxRows, boxCols: boxCols)
        self.init(validatedSize: size, boxRows: boxRows, boxCols: boxCols)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Int.self, forKey: .size)
        let boxRows = try container.decodeIfPresent(Int.self, forKey: .boxRows)
        let boxCols = try container.decodeIfPresent(Int.self, forKey: .boxCols)
        do {
            try self.init(size: size, boxRows: boxRows, boxCols: boxCols)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "value does not match a supported ruleset",
                    underlyingError: error
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(boxRows, forKey: .boxRows)
        try container.encode(boxCols, forKey: .boxCols)
    }

    private init(validatedSize size: Int, boxRows: Int?, boxCols: Int?) {
        self.size = size
        self.boxRows = boxRows
        self.boxCols = boxCols
    }

    private enum CodingKeys: String, CodingKey {
        case size
        case boxRows
        case boxCols
    }

    /// 三种标准规格以外都拒绝，避免半合法规则流到求解器。
    private static func validate(size: Int, boxRows: Int?, boxCols: Int?) throws {
        guard supportedSizes.contains(size) else {
            throw ValidationError.unsupportedSize(size)
        }
        switch (size, boxRows, boxCols) {
        case (4, 2, 2), (9, 3, 3), (5, nil, nil):
            return
        default:
            throw ValidationError.invalidBoxDimensions(size: size, boxRows: boxRows, boxCols: boxCols)
        }
    }
}
