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
    public let difficulty: Difficulty
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
        addedAt: Date
    ) {
        self.id = id
        self.size = size
        self.givens = givens
        self.difficulty = difficulty
        self.seRating = seRating
        self.score = score
        self.source = source
        self.addedAt = addedAt
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
