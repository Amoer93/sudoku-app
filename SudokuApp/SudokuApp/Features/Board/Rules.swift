/// 数独规则。只接受 4×4、5×5、9×9，和冻结的引擎接口一样。
///
/// `boxRows` / `boxCols` 是一个宫内部的行数和列数。5×5 两者都是 nil。
/// 公开的初始化会校验，非法组合抛错，没有不抛错的成员初始化器。
struct Rules: Codable, Equatable, Hashable, Sendable {
    enum ValidationError: Error, Equatable, Sendable {
        case unsupportedSize(Int)
        case invalidBoxDimensions(size: Int, boxRows: Int?, boxCols: Int?)
    }

    static let supportedSizes: [Int] = [4, 5, 9]

    static let fourByFour = Rules(validatedSize: 4, boxRows: 2, boxCols: 2)
    static let fiveByFive = Rules(validatedSize: 5, boxRows: nil, boxCols: nil)
    static let nineByNine = Rules(validatedSize: 9, boxRows: 3, boxCols: 3)

    let size: Int
    let boxRows: Int?
    let boxCols: Int?

    var hasBoxes: Bool {
        boxRows != nil && boxCols != nil
    }

    var cellCount: Int {
        size * size
    }

    init(size: Int, boxRows: Int?, boxCols: Int?) throws {
        try Self.validate(size: size, boxRows: boxRows, boxCols: boxCols)
        self.init(validatedSize: size, boxRows: boxRows, boxCols: boxCols)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let size = try container.decode(Int.self, forKey: .size)
        let boxRows = try container.decodeIfPresent(Int.self, forKey: .boxRows)
        let boxCols = try container.decodeIfPresent(Int.self, forKey: .boxCols)
        try self.init(size: size, boxRows: boxRows, boxCols: boxCols)
    }

    func encode(to encoder: Encoder) throws {
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
