import Foundation

/// 读写进度文件。文件位置可以注入，方便测试。
final class PuzzleProgressStore {
    /// 一次读取的结果。
    struct LoadResult {
        let records: PuzzleProgressRecords
        /// 文件来自更新版本的 App：只读，不能存盘。
        let isReadOnly: Bool
    }

    /// 只用来先看版本号，不关心其他字段。
    private struct SchemaHeader: Decodable {
        let schemaVersion: Int
    }

    let fileURL: URL
    private var isReadOnly = false

    init(fileURL: URL = PuzzleProgressStore.defaultFileURL()) {
        self.fileURL = fileURL
    }

    /// 默认放在 Application Support/PuzzleProgress 下。
    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PuzzleProgress/records.json")
    }

    /// 读文件；没有文件、文件损坏、版本太新都不抛错。
    func load() -> LoadResult {
        isReadOnly = false
        guard let data = try? Data(contentsOf: fileURL) else {
            return LoadResult(records: PuzzleProgressRecords(), isReadOnly: false)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        do {
            let header = try decoder.decode(SchemaHeader.self, from: data)
            if header.schemaVersion > PuzzleProgressRecords.currentSchemaVersion {
                // 新版本的文件：原样留着，本次只读，避免旧版本把新数据盖掉
                isReadOnly = true
                return LoadResult(records: PuzzleProgressRecords(), isReadOnly: true)
            }
            let records = try decoder.decode(PuzzleProgressRecords.self, from: data)
            return LoadResult(records: records, isReadOnly: false)
        } catch {
            // 坏文件先改名留着，不能让下次存盘悄悄盖掉
            moveCorruptFileAside()
            return LoadResult(records: PuzzleProgressRecords(), isReadOnly: false)
        }
    }

    /// 原子写入，写到一半崩溃也不会弄坏旧文件。只读状态下什么都不做。
    func save(_ records: PuzzleProgressRecords) throws {
        if isReadOnly {
            return
        }
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        try encoder.encode(records).write(to: fileURL, options: .atomic)
    }

    private func moveCorruptFileAside() {
        let folder = fileURL.deletingLastPathComponent()
        let seconds = Int(Date().timeIntervalSince1970)
        var target = folder.appendingPathComponent("records.corrupt-\(seconds).json")
        if FileManager.default.fileExists(atPath: target.path) {
            // 同一秒内再次损坏：加随机后缀，避免盖掉上一份
            target = folder.appendingPathComponent("records.corrupt-\(seconds)-\(UUID().uuidString).json")
        }
        try? FileManager.default.moveItem(at: fileURL, to: target)
    }
}
