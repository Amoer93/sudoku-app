import Foundation
import SudokuEngine

/// 一条“已完成”记录。
struct CompletedRecord: Codable, Equatable {
    let id: PuzzleFingerprint
    /// 第一次完成的时间，重复完成时不改。
    let completedAt: Date
    /// 完成次数。旧文件没有这个字段，读出来当 1 次。
    var completionCount: Int

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
    /// 内置题库的题才有难度；4×4、5×5 的固定题没有。
    let difficulty: Difficulty?
    /// 固定题的尺寸（4 或 5）；题库题可以不写。
    let size: Int?
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
