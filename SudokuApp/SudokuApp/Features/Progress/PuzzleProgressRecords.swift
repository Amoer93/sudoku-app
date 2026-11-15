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
    let difficulty: Difficulty? // 固定题没有难度
    let size: Int? // 固定题的尺寸（4 或 5）
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
    var lastPlayedByDifficulty = LastPlayedByDifficulty()
    /// 4×4 / 5×5 固定题没有难度，单独记一条。
    var lastPlayedFixture: LastPlayedRecord?
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
    /// 是不是 4×4 / 5×5 的固定题：看尺寸，或看固定题的 id。
    var isFixture: Bool {
        size == 4 || size == 5 || id == HomeProgress.fixture4 || id == HomeProgress.fixture5
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
        // 旧文件只有 lastPlayed：把它搬进对应的档位或固定题，进度不丢
        if lastPlayedByDifficulty.all.isEmpty, lastPlayedFixture == nil, let lastPlayed {
            place(lastPlayed)
        }
    }

    /// 记下刚玩的题：只动它自己的档位（或固定题），其他档位不变；旧字段总是写刚记下的这一条。
    mutating func recordLastPlayed(_ record: LastPlayedRecord) {
        place(record)
        lastPlayed = record
    }

    private mutating func place(_ record: LastPlayedRecord) {
        if record.isFixture {
            lastPlayedFixture = record
        } else if let difficulty = record.difficulty {
            lastPlayedByDifficulty[difficulty] = record
        }
    }
}
