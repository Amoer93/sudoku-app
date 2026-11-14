import Foundation
import SudokuEngine

/// 读存档的结果：没存过、读不出来、来自更新版本、读到了。
enum BoardSessionLoadResult: Equatable {
    case none, unreadable, newerVersion
    case loaded(BoardSessionState)
}

/// 首页用的存档概况：只看文件头，不解码整盘。只有 inProgress 算「玩到一半」。
enum BoardSessionSummary: Equatable {
    case none, newerVersion, autoSolved, inProgress
}

/// 读写进行中棋盘的存档，一道题一个文件。磁盘错误都不外抛，也绝不碰 records.json。
final class BoardSessionStore {
    static let defaultMaxFileSize = 1_000_000

    /// 文件头：只取版本、全解标记和指纹；后两项读不出来就当没有。
    private struct SchemaHeader: Decodable {
        let schemaVersion: Int
        let usedAutoSolve: Bool?
        let puzzleID: PuzzleFingerprint?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            usedAutoSolve = try? container.decode(Bool.self, forKey: .usedAutoSolve)
            puzzleID = try? container.decode(PuzzleFingerprint.self, forKey: .puzzleID)
        }

        private enum Keys: String, CodingKey { case schemaVersion, usedAutoSolve, puzzleID }
    }

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

    /// 读出并校验，不对就返回 nil。只是 loadResult 的简写。
    func load(puzzleID: PuzzleFingerprint, puzzle: SamplePuzzle) -> BoardSessionState? {
        if case .loaded(let state) = loadResult(puzzleID: puzzleID, puzzle: puzzle) { return state }
        return nil
    }

    /// 读出并校验。坏文件改名留着；新版本的文件原样不动，也不算坏。
    func loadResult(puzzleID: PuzzleFingerprint, puzzle: SamplePuzzle) -> BoardSessionLoadResult {
        guard hasFile(for: puzzleID) else { return .none }
        let url = fileURL(for: puzzleID)
        // 先看版本号再解码：新版本的文件解不开，也不能当坏文件改名
        let version = header(at: url)?.schemaVersion
        if let version, version > BoardSessionState.currentSchemaVersion { return .newerVersion }
        guard version != nil, let data = try? Data(contentsOf: url),
              let state = BoardSessionState.decode(from: data) else {
            moveCorruptFileAside(url, id: puzzleID)
            return .unreadable
        }
        // 文件里记的指纹要和文件名对得上
        guard state.puzzleID == puzzleID,
              let valid = state.validated(against: puzzle, puzzleID: puzzleID) else {
            moveCorruptFileAside(url, id: puzzleID) // 读得出但和这道题对不上，也挪开，免得每次都提示
            return .unreadable
        }
        return .loaded(valid)
    }

    /// 只看文件头的概况，首页用，不解码整盘。
    func summary(for id: PuzzleFingerprint) -> BoardSessionSummary {
        summary(of: header(at: fileURL(for: id)), expecting: id)
    }

    /// 扫一遍文件夹，返回所有「玩到一半」的题；每个文件只读文件头。
    func inProgressIDs() -> Set<PuzzleFingerprint> {
        Set(scan().filter { $0.value == .inProgress }.keys)
    }

    /// 能「重新开始」的题：玩到一半的，加上用过全解留下存档的。
    func restartableIDs() -> Set<PuzzleFingerprint> { Set(scan().keys) }

    /// 删掉题已不存在的存档（只看当前版本、读得出指纹的）；新版本和 .corrupt- 文件不动。
    func removeOrphans(keeping knownIDs: Set<PuzzleFingerprint>) {
        for id in scan().keys where !knownIDs.contains(id) { remove(puzzleID: id) }
    }

    /// 把这道题的存档挪开留底（恢复不出来时用）；新版本的文件不动。
    func moveAside(puzzleID: PuzzleFingerprint) {
        let url = fileURL(for: puzzleID)
        if hasFile(for: puzzleID), !hasNewerSchema(at: url) { moveCorruptFileAside(url, id: puzzleID) }
    }

    /// 文件夹里当前版本的存档：只含「玩到一半」和「全解」两种。
    private func scan() -> [PuzzleFingerprint: BoardSessionSummary] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        var found: [PuzzleFingerprint: BoardSessionSummary] = [:]
        for url in urls where url.pathExtension == "json" {
            // 文件名要和里面记的指纹对得上，改名留下的坏文件会被挡掉
            guard let header = header(at: url), let id = header.puzzleID,
                  fileURL(for: id).lastPathComponent == url.lastPathComponent else { continue }
            let kind = summary(of: header, expecting: id)
            if kind == .inProgress || kind == .autoSolved { found[id] = kind }
        }
        return found
    }

    private func summary(of header: SchemaHeader?, expecting id: PuzzleFingerprint) -> BoardSessionSummary {
        guard let header else { return .none }
        if header.schemaVersion > BoardSessionState.currentSchemaVersion { return .newerVersion }
        let isCurrent = header.schemaVersion == BoardSessionState.currentSchemaVersion
        guard isCurrent, header.puzzleID == id else { return .none }
        return header.usedAutoSolve == true ? .autoSolved : .inProgress
    }

    /// 只删这道题的存档；新版本的文件不删。
    func remove(puzzleID: PuzzleFingerprint) {
        let url = fileURL(for: puzzleID)
        if !hasNewerSchema(at: url) { try? FileManager.default.removeItem(at: url) }
    }

    /// 文件头；太大、读不出来、不是 JSON 都返回 nil。
    private func header(at url: URL) -> SchemaHeader? {
        let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= maxFileSize, let data = try? Data(contentsOf: url) else { return nil }
        return try? BoardSessionState.makeDecoder().decode(SchemaHeader.self, from: data)
    }

    private func hasNewerSchema(at url: URL) -> Bool {
        (header(at: url)?.schemaVersion ?? 0) > BoardSessionState.currentSchemaVersion
    }

    private func moveCorruptFileAside(_ url: URL, id: PuzzleFingerprint) {
        // 加随机后缀，同一秒内再次损坏也不会盖掉上一份
        let name = "\(Self.sanitizedName(for: id)).corrupt-\(Int(Date().timeIntervalSince1970))-\(UUID()).json"
        try? FileManager.default.moveItem(at: url, to: folderURL.appendingPathComponent(name))
    }
}
