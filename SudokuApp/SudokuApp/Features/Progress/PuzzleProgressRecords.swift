import Foundation
import SudokuEngine

/// 一条“已完成”记录。
struct CompletedRecord: Codable, Equatable {
    let id: PuzzleFingerprint
    let completedAt: Date // 第一次完成的时间，重复完成不改
    var completionCount: Int // 旧文件没有这个字段，当 1 次

    init(id: PuzzleFingerprint, completedAt: Date, completionCount: Int = 1) {
        self.id = id
        self.completedAt = completedAt
        self.completionCount = completionCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(PuzzleFingerprint.self, forKey: .id)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        completionCount = try container.decodeIfPresent(Int.self, forKey: .completionCount) ?? 1
    }
}

/// 最近一次玩的题。
struct LastPlayedRecord: Codable, Equatable {
    let id: PuzzleFingerprint
    let difficulty: Difficulty? // 固定题和导入题没有难度
    let size: Int? // 题的边长；很早的记录没有，当 9×9
    let playedAt: Date

    init(id: PuzzleFingerprint, difficulty: Difficulty? = nil, size: Int? = nil, playedAt: Date) {
        self.id = id
        self.difficulty = difficulty
        self.size = size
        self.playedAt = playedAt
    }
}

/// records.json 的内容。
struct PuzzleProgressRecords: Codable, Equatable {
    /// 当前 App 能读懂的格式版本。
    static let currentSchemaVersion = 1

    var schemaVersion: Int = PuzzleProgressRecords.currentSchemaVersion
    var completed: [CompletedRecord] = []
    /// 所有档位和固定题里最近的一条。只为旧字段还能读；首页的 ▶ 不看它。
    var lastPlayed: LastPlayedRecord?
    /// 9×9 内置题，每个难度一条。
    var lastPlayedByDifficulty = LastPlayedByDifficulty()
    /// 旧版 4×4 / 5×5 固定题没有难度，单独记一条。新首页不再打开它们，只为旧文件留着。
    var lastPlayedFixture: LastPlayedRecord?
    /// 4×4 / 5×5 内置题，每个尺寸、每个难度一条。
    var lastPlayedBySmallBoard = LastPlayedBySmallBoard()

    /// 某尺寸、某难度上次玩的内置题；首页的 ▶ 看这一条。
    func lastPlayed(size: Int, difficulty: Difficulty) -> LastPlayedRecord? {
        if size == 9 {
            return lastPlayedByDifficulty[difficulty]
        }
        return lastPlayedBySmallBoard[size, difficulty]
    }
}

/// 小棋盘各记一道上次玩的内置题。和 9×9 一样用固定字段，方便编解码。
struct LastPlayedBySmallBoard: Codable, Equatable {
    var fourEasy: LastPlayedRecord?
    var fourHard: LastPlayedRecord?
    var fiveEasy: LastPlayedRecord?
    var fiveHard: LastPlayedRecord?

    var all: [LastPlayedRecord] { [fourEasy, fourHard, fiveEasy, fiveHard].compactMap { $0 } }

    /// 没有对应槽的组合（比如 4×4 中等）读出来是空，写进去不记。
    subscript(size: Int, difficulty: Difficulty) -> LastPlayedRecord? {
        get {
            switch (size, difficulty) {
            case (4, .easy): return fourEasy
            case (4, .hard): return fourHard
            case (5, .easy): return fiveEasy
            case (5, .hard): return fiveHard
            default: return nil
            }
        }
        set {
            switch (size, difficulty) {
            case (4, .easy): fourEasy = newValue
            case (4, .hard): fourHard = newValue
            case (5, .easy): fiveEasy = newValue
            case (5, .hard): fiveHard = newValue
            default: break
            }
        }
    }
}

/// 每个难度各记一道上次玩的 9×9 题。用四个字段而不是字典：Difficulty 是 Int，当字典键不好编解码。
struct LastPlayedByDifficulty: Codable, Equatable {
    var easy: LastPlayedRecord?
    var medium: LastPlayedRecord?
    var hard: LastPlayedRecord?
    var expert: LastPlayedRecord?

    var all: [LastPlayedRecord] { [easy, medium, hard, expert].compactMap { $0 } }

    subscript(difficulty: Difficulty) -> LastPlayedRecord? {
        get {
            switch difficulty {
            case .easy: return easy
            case .medium: return medium
            case .hard: return hard
            case .expert: return expert
            }
        }
        set {
            switch difficulty {
            case .easy: easy = newValue
            case .medium: medium = newValue
            case .hard: hard = newValue
            case .expert: expert = newValue
            }
        }
    }
}

extension LastPlayedRecord {
    /// 是不是旧版 4×4 / 5×5 的固定题：只认那两个 id。不能看尺寸，小棋盘现在也有题库题。
    var isFixture: Bool {
        id == HomeProgress.fixture4 || id == HomeProgress.fixture5
    }
}

extension PuzzleProgressRecords {
    /// 新字段都用 decodeIfPresent，旧文件照常能读；版本号不用升。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        completed = try container.decode([CompletedRecord].self, forKey: .completed)
        lastPlayed = try container.decodeIfPresent(LastPlayedRecord.self, forKey: .lastPlayed)
        lastPlayedByDifficulty = try container.decodeIfPresent(
            LastPlayedByDifficulty.self, forKey: .lastPlayedByDifficulty
        ) ?? LastPlayedByDifficulty()
        lastPlayedFixture = try container.decodeIfPresent(LastPlayedRecord.self, forKey: .lastPlayedFixture)
        lastPlayedBySmallBoard = try container.decodeIfPresent(
            LastPlayedBySmallBoard.self, forKey: .lastPlayedBySmallBoard
        ) ?? LastPlayedBySmallBoard()
        // 旧文件只有 lastPlayed：把它搬进对应的档位或固定题，进度不丢
        let hasNoSlots = lastPlayedByDifficulty.all.isEmpty && lastPlayedBySmallBoard.all.isEmpty
        if hasNoSlots, lastPlayedFixture == nil, let lastPlayed {
            place(lastPlayed)
        }
    }

    /// 记下刚玩的题：只动它自己尺寸和难度的那一条（或固定题），其他的不变；旧字段总是写刚记下的这一条。
    mutating func recordLastPlayed(_ record: LastPlayedRecord) {
        place(record)
        lastPlayed = record
    }

    /// 按（尺寸 + 难度）放进自己的槽。没有难度的（导入题）不占任何槽。
    private mutating func place(_ record: LastPlayedRecord) {
        if record.isFixture {
            lastPlayedFixture = record
            return
        }
        guard let difficulty = record.difficulty else {
            return
        }
        let size = record.size ?? 9
        if size == 9 {
            lastPlayedByDifficulty[difficulty] = record
        } else {
            lastPlayedBySmallBoard[size, difficulty] = record
        }
    }
}
