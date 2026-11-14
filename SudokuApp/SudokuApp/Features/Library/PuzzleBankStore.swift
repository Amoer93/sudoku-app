import Foundation
import SudokuEngine

/// 把用户导入的题存到文件里。文件位置可以注入，方便测试。
struct PuzzleBankStore {
    let fileURL: URL

    init(fileURL: URL = PuzzleBankStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    /// 默认放在 Application Support/PuzzleBank 下。
    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PuzzleBank/user-entries.json")
    }

    /// 读文件的结果：题库，加上能不能据此清理孤儿存档。
    struct LoadResult {
        let bank: PuzzleBank
        /// 只有「文件读成功」或「真的没有文件（旁边也没有坏文件备份）」时为 true。
        let allowsOrphanCleanup: Bool
    }

    /// 读文件；没有文件或文件损坏都退回内置题，永远不抛错。
    func load() -> PuzzleBank { loadResult().bank }

    /// 同 load()，另外说明这次的题库能不能当作「全部题」来清理存档。
    func loadResult() -> LoadResult {
        // 内置题都读不出来时，只能给空题库
        guard let builtinOnly = try? PuzzleBank.load(userData: nil) else {
            return LoadResult(bank: PuzzleBank(), allowsOrphanCleanup: false)
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // 文件不见了，但旁边有坏文件的备份：说明是上次损坏挪走的，不是真没导入过
            return LoadResult(bank: builtinOnly, allowsOrphanCleanup: !hasCorruptLeftover())
        }
        // 文件在但读不出来：退回内置题，但导入题的存档不能删
        guard let data = try? Data(contentsOf: fileURL) else {
            return LoadResult(bank: builtinOnly, allowsOrphanCleanup: false)
        }
        do {
            return LoadResult(bank: try PuzzleBank.load(userData: data), allowsOrphanCleanup: true)
        } catch {
            // 坏文件先改名留着，不能让下次存盘悄悄盖掉
            moveCorruptFileAside()
            return LoadResult(bank: builtinOnly, allowsOrphanCleanup: false)
        }
    }

    /// 原子写入，写到一半崩溃也不会弄坏旧文件。
    func save(_ bank: PuzzleBank) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bank.userEntriesData().write(to: fileURL, options: .atomic)
    }

    private static let corruptPrefix = "user-entries.corrupt-"
    private static let corruptSuffix = ".json"

    /// 同一个文件夹里有没有之前挪开的坏文件。
    private func hasCorruptLeftover() -> Bool {
        let folder = fileURL.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names {
            if name.hasPrefix(Self.corruptPrefix) && name.hasSuffix(Self.corruptSuffix) {
                return true
            }
        }
        return false
    }

    private func moveCorruptFileAside() {
        let folder = fileURL.deletingLastPathComponent()
        let seconds = Int(Date().timeIntervalSince1970)
        var target = folder.appendingPathComponent("\(Self.corruptPrefix)\(seconds)\(Self.corruptSuffix)")
        if FileManager.default.fileExists(atPath: target.path) {
            // 同一秒内再次损坏：加随机后缀，避免盖掉上一份
            let uniqueName = "\(Self.corruptPrefix)\(seconds)-\(UUID().uuidString)\(Self.corruptSuffix)"
            target = folder.appendingPathComponent(uniqueName)
        }
        try? FileManager.default.moveItem(at: fileURL, to: target)
    }
}
