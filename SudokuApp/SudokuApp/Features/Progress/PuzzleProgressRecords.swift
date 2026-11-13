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
    var lastPlayed: LastPlayedRecord?
}
