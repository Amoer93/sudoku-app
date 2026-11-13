import SudokuEngine

/// 首页进度文案。测试直接断言这些字符串。
enum ProgressCopy {
    static let intro = "选一个难度,再点一道题开始吧！"
    static let zeroDone = "还没做完过题,从第 1 题开始吧！"
    static let allDone = "这一档全部做完啦,你太厉害了！"
    static let lastPlayedNone = "还没玩过,先选一道题吧"
    static let random = "随机来一题"
    static let smallBoards = "小棋盘练习"
    static let emptyDifficulty = "这一档还没有题目,先玩玩小棋盘吧"
    static func progress(done: Int, total: Int) -> String { "已经做完 \(done) 道,一共 \(total) 道" }
    static func progressVoiceOver(done: Int, total: Int) -> String { "这一档做完了 \(done) 道,一共 \(total) 道" }
    static func cumulative(_ count: Int) -> String { "一共做完了 \(count) 道题,真棒！" }
    static func lastPlayedFixture(size: Int) -> String { "上次玩的:\(size)×\(size)" }
    static func lastPlayedBank(difficulty: Difficulty, number: Int?) -> String {
        guard let number else { return "上次玩的:" + LibraryCopy.title(difficulty) }
        return "上次玩的:\(LibraryCopy.title(difficulty)) · 第 \(number) 题"
    }
    static func tileVoiceOver(number: Int, isCompleted: Bool) -> String {
        "第 \(number) 题,\(isCompleted ? "已经做完" : "新题")"
    }
}

extension PuzzleBankProviding {
    /// 某难度的内置题，按难度从易到难排；首页格子和进度都只看这份。
    func builtinEntries(difficulty: Difficulty) -> [PuzzleBankEntry] {
        entries(difficulty: difficulty, source: .builtin, sort: .difficultyAscending)
    }
}

/// 首页某一档的进度：纯计算，不依赖界面。
struct HomeProgress {
    struct Tile: Identifiable {
        let number: Int // 从 1 开始
        let entry: PuzzleBankEntry
        let isCompleted: Bool
        let isLastPlayed: Bool
        var id: PuzzleFingerprint { entry.id }
    }

    static let fixture4 = PuzzleFingerprint(value: "fixture-4")
    static let fixture5 = PuzzleFingerprint(value: "fixture-5")

    let entries: [PuzzleBankEntry]
    let records: PuzzleProgressRecords
    private let completedIDs: Set<PuzzleFingerprint>

    init(entries: [PuzzleBankEntry], records: PuzzleProgressRecords = PuzzleProgressRecords()) {
        self.entries = entries
        self.records = records
        completedIDs = Set(records.completed.map(\.id))
    }

    var total: Int { entries.count }
    /// 只数还在这份列表里的、不同的已做完题。
    var doneCount: Int { entries.filter { completedIDs.contains($0.id) }.count }
    var fraction: Double { total == 0 ? 0 : Double(doneCount) / Double(total) }
    var totalCompletions: Int { records.completed.reduce(0) { $0 + $1.completionCount } }

    var tiles: [Tile] {
        entries.enumerated().map { offset, entry in
            Tile(number: offset + 1, entry: entry, isCompleted: completedIDs.contains(entry.id),
                 isLastPlayed: records.lastPlayed?.id == entry.id)
        }
    }

    func isCompleted(_ id: PuzzleFingerprint) -> Bool { completedIDs.contains(id) }

    var summaryText: String {
        if total == 0 { return ProgressCopy.emptyDifficulty }
        if doneCount == total { return ProgressCopy.allDone }
        if doneCount == 0 { return ProgressCopy.zeroDone }
        return ProgressCopy.progress(done: doneCount, total: total)
    }

    /// 优先抽没做完的；全做完了就从全部里抽。
    func randomEntry<G: RandomNumberGenerator>(using generator: inout G) -> PuzzleBankEntry? {
        let fresh = entries.filter { !completedIDs.contains($0.id) }
        return (fresh.isEmpty ? entries : fresh).randomElement(using: &generator)
    }

    /// 「上次玩的」那一行；固定题和题库题分开处理。
    static func lastPlayedText(_ record: LastPlayedRecord?, bank: any PuzzleBankProviding) -> String {
        guard let record else { return ProgressCopy.lastPlayedNone }
        if record.id == fixture4 || record.size == 4 { return ProgressCopy.lastPlayedFixture(size: 4) }
        if record.id == fixture5 || record.size == 5 { return ProgressCopy.lastPlayedFixture(size: 5) }
        guard let difficulty = record.difficulty else { return ProgressCopy.lastPlayedNone }
        let position = bank.builtinEntries(difficulty: difficulty).firstIndex { $0.id == record.id }
        return ProgressCopy.lastPlayedBank(difficulty: difficulty, number: position.map { $0 + 1 })
    }
}
