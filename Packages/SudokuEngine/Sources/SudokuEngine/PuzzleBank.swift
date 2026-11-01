import Foundation

/// 题目来源。
public enum PuzzleSource: String, Codable, CaseIterable, Hashable, Sendable {
    case builtin, userUpload
}

/// 题库条目。
public struct PuzzleBankEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: PuzzleFingerprint
    public let size: Int
    public let givens: [Int]
    /// 实际使用的档位（筛选、排序都看它）。有 `tierOverride` 时就等于覆盖值。
    public let difficulty: Difficulty
    /// 仅内置题使用：记录该题被人工指定了档位，和评分器给出的档位不同。
    /// 为 nil 时 `difficulty` 就是评分器的结果；nil 不会写进 JSON。
    public let tierOverride: Difficulty?
    public let seRating: Double
    public let score: Int
    public let source: PuzzleSource
    public let addedAt: Date

    public init(
        id: PuzzleFingerprint,
        size: Int,
        givens: [Int],
        difficulty: Difficulty,
        seRating: Double,
        score: Int,
        source: PuzzleSource,
        addedAt: Date,
        tierOverride: Difficulty? = nil
    ) {
        self.id = id
        self.size = size
        self.givens = givens
        // 用户上传的题不允许覆盖档位，直接丢掉
        let allowedOverride = source == .builtin ? tierOverride : nil
        self.difficulty = allowedOverride ?? difficulty
        self.tierOverride = allowedOverride
        self.seRating = seRating
        self.score = score
        self.source = source
        self.addedAt = addedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, size, givens, difficulty, tierOverride, seRating, score, source, addedAt
    }

    /// 自定义解码：旧数据没有 `tierOverride` 也能读；经由 init 统一处理覆盖规则。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(PuzzleFingerprint.self, forKey: .id),
            size: try container.decode(Int.self, forKey: .size),
            givens: try container.decode([Int].self, forKey: .givens),
            difficulty: try container.decode(Difficulty.self, forKey: .difficulty),
            seRating: try container.decode(Double.self, forKey: .seRating),
            score: try container.decode(Int.self, forKey: .score),
            source: try container.decode(PuzzleSource.self, forKey: .source),
            addedAt: try container.decode(Date.self, forKey: .addedAt),
            tierOverride: try container.decodeIfPresent(Difficulty.self, forKey: .tierOverride)
        )
    }
}

/// 排序方式。
public enum PuzzleSort: Sendable {
    case difficultyAscending, difficultyDescending, addedAtNewest, addedAtOldest, sourceThenDifficulty
}

/// 加载错误。
public enum PuzzleBankLoadError: Error, Equatable, Sendable { case missingResource }

/// 入库错误。
public enum BankError: Error, Equatable, Sendable {
    case duplicate(existing: PuzzleBankEntry)
    case ungradable(GradeError)
    case unsupportedSize
}

/// 数独题库。
public struct PuzzleBank: Codable, Sendable {
    public private(set) var entries: [PuzzleBankEntry]

    public init(entries: [PuzzleBankEntry] = []) {
        self.entries = entries
    }

    public static func loadBuiltin() throws -> [PuzzleBankEntry] {
        try loadBuiltin(bundle: .module)
    }

    public static func loadBuiltin(bundle: Bundle) throws -> [PuzzleBankEntry] {
        guard let url = bundle.url(forResource: "BuiltinPuzzles", withExtension: "json") else {
            throw PuzzleBankLoadError.missingResource
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode([PuzzleBankEntry].self, from: Data(contentsOf: url))
    }

    public static func load(userData: Data?) throws -> PuzzleBank {
        try load(builtinBundle: .module, userData: userData)
    }

    /// 加载内置题库，并可选地合并用户数据。
    ///
    /// 如果 `userData` 为 `nil`，仅返回内置题库。用户数据损坏时会抛出错误，
    /// 调用方应捕获错误并回退为仅加载内置题库。
    /// 注意：此方法不校验用户条目的 `id`（指纹）与 `size`。
    public static func load(builtinBundle: Bundle, userData: Data?) throws -> PuzzleBank {
        let builtins = try loadBuiltin(bundle: builtinBundle)
        var seen = Set(builtins.map(\.id))
        var entries = builtins
        if let data = userData {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let userEntries = try decoder.decode([PuzzleBankEntry].self, from: data)
            for entry in userEntries where entry.source == .userUpload && seen.insert(entry.id).inserted {
                entries.append(entry)
            }
        }
        return PuzzleBank(entries: entries)
    }

    /// 将题目加入题库。
    ///
    /// - Parameter grid: 题面，仅应传入原始给定的数字（givens），不要传已填写或含用户输入的盘面。
    public mutating func add(
        _ grid: Grid,
        rules: Rules,
        source: PuzzleSource = .userUpload,
        now: Date = Date()
    ) -> Result<PuzzleBankEntry, BankError> {
        guard rules == .nineByNine && grid.size == 9 else { return .failure(.unsupportedSize) }
        let fingerprint = PuzzleCanonicalizer.fingerprint(grid, rules: .nineByNine)
        if let existing = entries.first(where: { $0.id == fingerprint }) {
            return .failure(.duplicate(existing: existing))
        }
        switch DifficultyGrader.grade(grid, rules: .nineByNine) {
        case .failure(let error):
            return .failure(.ungradable(error))
        case .success(let grade):
            let entry = PuzzleBankEntry(
                id: fingerprint,
                size: 9,
                givens: grid.cells,
                difficulty: grade.difficulty,
                seRating: grade.seRating,
                score: grade.score,
                source: source,
                addedAt: now
            )
            entries.append(entry)
            return .success(entry)
        }
    }

    public func entries(
        difficulty: Difficulty? = nil,
        source: PuzzleSource? = nil,
        sort: PuzzleSort = .difficultyAscending
    ) -> [PuzzleBankEntry] {
        var result = entries
        if let difficulty { result = result.filter { $0.difficulty == difficulty } }
        if let source { result = result.filter { $0.source == source } }
        result.sort { compare(sortKey(for: $0, sort: sort), sortKey(for: $1, sort: sort)) }
        return result
    }

    public func randomEntry<G: RandomNumberGenerator>(
        difficulty: Difficulty? = nil,
        source: PuzzleSource? = nil,
        using generator: inout G
    ) -> PuzzleBankEntry? {
        let filtered = entries(difficulty: difficulty, source: source, sort: .difficultyAscending)
        return filtered.randomElement(using: &generator)
    }

    public func randomEntry(difficulty: Difficulty? = nil, source: PuzzleSource? = nil) -> PuzzleBankEntry? {
        var generator = SystemRandomNumberGenerator()
        return randomEntry(difficulty: difficulty, source: source, using: &generator)
    }

    public func userEntriesData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        let userEntries = entries
            .filter { $0.source == .userUpload }
            .sorted { compare(sortKey(for: $0, sort: .addedAtOldest), sortKey(for: $1, sort: .addedAtOldest)) }
        return try encoder.encode(userEntries)
    }
}

private typealias SortKey = [SortComponent]

private enum SortComponent: Comparable {
    case int(Int), double(Double), string(String)

    static func < (lhs: SortComponent, rhs: SortComponent) -> Bool {
        switch (lhs, rhs) {
        case (.int(let left), .int(let right)): return left < right
        case (.double(let left), .double(let right)): return left < right
        case (.string(let left), .string(let right)): return left < right
        default: return false
        }
    }
}

private func sortKey(for entry: PuzzleBankEntry, sort: PuzzleSort) -> SortKey {
    switch sort {
    case .difficultyAscending:
        return [.int(entry.difficulty.rawValue), .int(entry.score), .string(entry.id.value)]
    case .difficultyDescending:
        return [.int(-entry.difficulty.rawValue), .int(-entry.score), .string(entry.id.value)]
    case .addedAtNewest:
        return [.double(-entry.addedAt.timeIntervalSince1970), .string(entry.id.value)]
    case .addedAtOldest:
        return [.double(entry.addedAt.timeIntervalSince1970), .string(entry.id.value)]
    case .sourceThenDifficulty:
        let sourceOrder = entry.source == .builtin ? 0 : 1
        return [.int(sourceOrder), .int(entry.difficulty.rawValue), .int(entry.score), .string(entry.id.value)]
    }
}

private func compare(_ lhs: SortKey, _ rhs: SortKey) -> Bool {
    for (left, right) in zip(lhs, rhs) where left != right {
        return left < right
    }
    return lhs.count < rhs.count
}
