import Foundation
import SudokuEngine

/// 一条“已完成”记录。
struct CompletedRecord: Codable, Equatable {
    let id: PuzzleFingerprint
    let completedAt: Date
}

/// 最近一次玩的题。
struct LastPlayedRecord: Codable, Equatable {
    let id: PuzzleFingerprint
    let difficulty: Difficulty
    let playedAt: Date
}

/// records.json 的内容。
struct PuzzleProgressRecords: Codable, Equatable {
    /// 当前 App 能读懂的格式版本。
    static let currentSchemaVersion = 1

    var schemaVersion: Int = PuzzleProgressRecords.currentSchemaVersion
    var completed: [CompletedRecord] = []
    var lastPlayed: LastPlayedRecord?
}
