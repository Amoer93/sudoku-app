import os
import SudokuEngine

/// 拍照导入的入库文案。
enum ImportBankCopy {
    static let duplicate = "该题已在题库"
    static let ungradable = "无法评级，未入库"
    static let openExisting = "打开已有题目"
    static func added(_ difficulty: Difficulty) -> String {
        "已加入题库：\(LibraryCopy.title(difficulty))"
    }
}

/// 入库的结果：给界面看的提示，以及重复时已有的那一条。
struct ImportNotice: Equatable {
    let text: String
    let existingEntry: PuzzleBankEntry?
}

/// 把识别出的题加进题库，成功后存盘。指纹和评级很慢，所以放在 actor 里，不占主线程。
/// 注意：题库在内存里只属于本实例，多个实例会各存各的、互相覆盖文件。
/// 所以正式环境必须只用一个实例，请用 `LibraryImporter.shared`。
actor LibraryImporter {
    private static let logger = Logger(subsystem: "SudokuApp", category: "LibraryImporter")
    private var bank: PuzzleBank
    private let persist: @Sendable (PuzzleBank) throws -> Void

    init(bank: PuzzleBank, persist: @escaping @Sendable (PuzzleBank) throws -> Void) {
        self.bank = bank
        self.persist = persist
    }

    /// 全 App 共用的唯一实例，避免多个实例互相覆盖存盘文件。
    static let shared = live()

    /// 正式环境：从文件读题库，成功入库后写回文件。
    static func live(store: PuzzleBankStore = PuzzleBankStore()) -> LibraryImporter {
        LibraryImporter(bank: store.load()) { current in try store.save(current) }
    }

    /// 入库并返回提示。只有成功才存盘；存盘失败不影响提示，题照样能玩。
    func add(_ grid: Grid, rules: Rules) -> ImportNotice {
        // 先查尺寸，不支持的尺寸不进引擎
        guard rules.size == 9, grid.size == 9,
              let (engineGrid, engineRules) = EngineBoardAdapter.convert(grid, rules)
        else {
            return ImportNotice(text: LibraryCopy.message(.unsupportedSize), existingEntry: nil)
        }
        switch bank.add(engineGrid, rules: engineRules, source: .userUpload) {
        case .success(let entry):
            savePersistently()
            return ImportNotice(text: ImportBankCopy.added(entry.difficulty), existingEntry: nil)
        case .failure(let error):
            return notice(for: error)
        }
    }

    private func notice(for error: BankError) -> ImportNotice {
        switch error {
        case .duplicate(let existing):
            return ImportNotice(text: ImportBankCopy.duplicate, existingEntry: existing)
        case .unsupportedSize:
            return ImportNotice(text: LibraryCopy.message(.unsupportedSize), existingEntry: nil)
        case .ungradable(let reason):
            return ImportNotice(text: LibraryCopy.message(reason), existingEntry: nil)
        }
    }

    private func savePersistently() {
        do {
            try persist(bank)
        } catch {
            // 存盘失败只丢持久化，内存里的题库仍可用；记一行日志方便排查
            Self.logger.error("Failed to save puzzle bank: \(error.localizedDescription, privacy: .public)")
        }
    }
}
