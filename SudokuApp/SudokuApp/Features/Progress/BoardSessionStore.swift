import Foundation
import SudokuEngine

/// 读写进行中棋盘的存档，一道题一个文件。磁盘错误都不外抛，也绝不碰 records.json。
final class BoardSessionStore {
    static let defaultMaxFileSize = 1_000_000
    private struct SchemaHeader: Decodable { let schemaVersion: Int }

    let folderURL: URL
    private let maxFileSize: Int

    init(
        folderURL: URL = BoardSessionStore.defaultFolderURL(),
        maxFileSize: Int = BoardSessionStore.defaultMaxFileSize
    ) {
        self.folderURL = folderURL
        self.maxFileSize = maxFileSize
    }

    /// 默认放在 records.json 旁边的 sessions 文件夹里。
    static func defaultFolderURL() -> URL {
        PuzzleProgressStore.defaultFileURL().deletingLastPathComponent()
            .appendingPathComponent("sessions", isDirectory: true)
    }

    /// 只留 ASCII 字母、数字和 - _ .，其他换成 _，指纹里的怪字符不能变成路径。
    static func sanitizedName(for id: PuzzleFingerprint) -> String {
        let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."
        return String(id.value.map { allowed.contains($0) ? $0 : "_" })
    }

    func fileURL(for id: PuzzleFingerprint) -> URL {
        folderURL.appendingPathComponent(Self.sanitizedName(for: id) + ".json")
    }

    /// 有没有存档文件（不管能不能读），用来区分「没存过」和「读不出来」。
    func hasFile(for id: PuzzleFingerprint) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    /// 原子写入。太大或磁盘出错就放弃；已有文件来自更新版本时不覆盖。
    func save(_ state: BoardSessionState) {
        let url = fileURL(for: state.puzzleID)
        guard let data = state.encoded(), data.count <= maxFileSize, !hasNewerSchema(at: url) else { return }
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            print("BoardSession save failed: \(error)") // 存不了不影响游戏，下次改动再试
        }
    }

    /// 读出并校验，不对就返回 nil。坏文件改名留着，新版本的文件原样不动。
    func load(puzzleID: PuzzleFingerprint, puzzle: SamplePuzzle) -> BoardSessionState? {
        guard hasFile(for: puzzleID) else { return nil }
        let url = fileURL(for: puzzleID)
        // 先看版本号再解码：新版本的文件解不开，也不能当坏文件改名
        let version = storedVersion(at: url)
        if let version, version > BoardSessionState.currentSchemaVersion { return nil }
        guard version != nil, let data = try? Data(contentsOf: url),
              let state = BoardSessionState.decode(from: data) else {
            moveCorruptFileAside(url, id: puzzleID)
            return nil
        }
        // 文件里记的指纹要和文件名对得上
        guard state.puzzleID == puzzleID else { return nil }
        return state.validated(against: puzzle, puzzleID: puzzleID)
    }

    /// 只删这道题的存档；新版本的文件不删。
    func remove(puzzleID: PuzzleFingerprint) {
        let url = fileURL(for: puzzleID)
        if !hasNewerSchema(at: url) { try? FileManager.default.removeItem(at: url) }
    }

    /// 文件里的版本号；太大、读不出来、不是 JSON 都返回 nil。
    private func storedVersion(at url: URL) -> Int? {
        let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= maxFileSize, let data = try? Data(contentsOf: url) else { return nil }
        return try? BoardSessionState.makeDecoder().decode(SchemaHeader.self, from: data).schemaVersion
    }

    private func hasNewerSchema(at url: URL) -> Bool {
        (storedVersion(at: url) ?? 0) > BoardSessionState.currentSchemaVersion
    }

    private func moveCorruptFileAside(_ url: URL, id: PuzzleFingerprint) {
        // 加随机后缀，同一秒内再次损坏也不会盖掉上一份
        let name = "\(Self.sanitizedName(for: id)).corrupt-\(Int(Date().timeIntervalSince1970))-\(UUID()).json"
        try? FileManager.default.moveItem(at: url, to: folderURL.appendingPathComponent(name))
    }
}
