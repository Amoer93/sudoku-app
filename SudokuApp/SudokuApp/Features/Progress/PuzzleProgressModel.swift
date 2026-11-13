import Foundation
import Observation
import SudokuEngine

/// 进度的内存状态：已完成的题、最近玩的题。改动后立刻存盘。
@MainActor
@Observable
final class PuzzleProgressModel {
    private(set) var records: PuzzleProgressRecords
    /// 文件来自更新版本时为 true，此时不会存盘。
    private(set) var isReadOnly: Bool

    @ObservationIgnored private let store: PuzzleProgressStore

    var lastPlayed: LastPlayedRecord? { records.lastPlayed }

    init(store: PuzzleProgressStore = PuzzleProgressStore()) {
        self.store = store
        let result = store.load()
        records = result.records
        isReadOnly = result.isReadOnly
    }

    /// 标记完成；已经完成过的题不重复记，也保留最早的完成时间。
    func markCompleted(id: PuzzleFingerprint, at date: Date = Date()) {
        let alreadyDone = records.completed.contains { $0.id == id }
        if alreadyDone {
            return
        }
        records.completed.append(CompletedRecord(id: id, completedAt: date))
        persist()
    }

    /// 记下最近玩的题。
    func setLastPlayed(id: PuzzleFingerprint, difficulty: Difficulty, at date: Date = Date()) {
        records.lastPlayed = LastPlayedRecord(id: id, difficulty: difficulty, playedAt: date)
        persist()
    }

    /// 只数出现在给定题目里的已完成题。
    func completedCount(in entries: [PuzzleBankEntry]) -> Int {
        let entryIDs = Set(entries.map(\.id))
        let doneIDs = Set(records.completed.map(\.id))
        return doneIDs.intersection(entryIDs).count
    }

    private func persist() {
        if isReadOnly {
            return
        }
        do {
            try store.save(records)
        } catch {
            // 存盘失败不影响当前游戏，下次改动会再试
            print("PuzzleProgress save failed: \(error)")
        }
    }
}
