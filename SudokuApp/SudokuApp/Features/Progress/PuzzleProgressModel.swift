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
    /// 进行中棋盘的存档；有自己的版本规则，不受 isReadOnly 影响。
    @ObservationIgnored let sessions: BoardSessionStore

    /// 有「玩到一半」存档的题（不含全解的）。只在 refreshSessionIndex 时更新，棋盘里存盘不会实时改它。
    private(set) var inProgressIDs: Set<PuzzleFingerprint> = []

    /// 能「重新开始这一题」的题（玩到一半 + 全解留下的）。同样只在刷新时更新。
    private(set) var restartableIDs: Set<PuzzleFingerprint> = []

    var lastPlayed: LastPlayedRecord? { records.lastPlayed }

    /// 重新扫一遍存档文件夹；回到首页时调用，因为刚关掉的棋盘可能写了或删了存档。
    /// 传了 knownIDs 就先清掉题已不存在的存档。
    func refreshSessionIndex(keeping knownIDs: Set<PuzzleFingerprint>? = nil) {
        let index = sessions.refreshIndex(keeping: knownIDs)
        inProgressIDs = index.inProgress
        restartableIDs = index.restartable
    }

    /// 清掉这道题的存档并刷新标记；完成记录不动（重新开始不等于没做过）。
    func restartPuzzle(id: PuzzleFingerprint) {
        sessions.remove(puzzleID: id)
        refreshSessionIndex()
    }

    func isCompleted(_ id: PuzzleFingerprint) -> Bool { records.completed.contains { $0.id == id } }

    init(store: PuzzleProgressStore = PuzzleProgressStore(), sessions: BoardSessionStore = BoardSessionStore()) {
        self.store = store
        self.sessions = sessions
        let result = store.load()
        records = result.records
        isReadOnly = result.isReadOnly
    }

    /// 标记完成。同一道题只留一条记录：重复完成只加次数，保留最早的完成时间。
    func markCompleted(id: PuzzleFingerprint, at date: Date = Date()) {
        if let position = records.completed.firstIndex(where: { $0.id == id }) {
            records.completed[position].completionCount += 1
        } else {
            records.completed.append(CompletedRecord(id: id, completedAt: date))
        }
        persist()
    }

    func setLastPlayed(id: PuzzleFingerprint, difficulty: Difficulty? = nil, size: Int? = nil, at date: Date = Date()) {
        records.lastPlayed = LastPlayedRecord(id: id, difficulty: difficulty, size: size, playedAt: date)
        persist()
    }

    var totalCompletions: Int {
        records.completed.reduce(0) { total, record in
            total + record.completionCount
        }
    }

    /// 只数出现在给定题目里、不同的已完成题；重复完成不增加。
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
