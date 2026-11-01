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

    /// 读文件；没有文件或文件损坏都退回内置题，永远不抛错。
    func load() -> PuzzleBank {
        // 内置题都读不出来时，只能给空题库
        guard let builtinOnly = try? PuzzleBank.load(userData: nil) else {
            return PuzzleBank()
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return builtinOnly
        }
        do {
            return try PuzzleBank.load(userData: data)
        } catch {
            // 坏文件先改名留着，不能让下次存盘悄悄盖掉
            moveCorruptFileAside()
            return builtinOnly
        }
    }

    /// 原子写入，写到一半崩溃也不会弄坏旧文件。
    func save(_ bank: PuzzleBank) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bank.userEntriesData().write(to: fileURL, options: .atomic)
    }

    private func moveCorruptFileAside() {
        let folder = fileURL.deletingLastPathComponent()
        let seconds = Int(Date().timeIntervalSince1970)
        var target = folder.appendingPathComponent("user-entries.corrupt-\(seconds).json")
        if FileManager.default.fileExists(atPath: target.path) {
            // 同一秒内再次损坏：加随机后缀，避免盖掉上一份
            target = folder.appendingPathComponent("user-entries.corrupt-\(seconds)-\(UUID().uuidString).json")
        }
        try? FileManager.default.moveItem(at: fileURL, to: target)
    }
}
