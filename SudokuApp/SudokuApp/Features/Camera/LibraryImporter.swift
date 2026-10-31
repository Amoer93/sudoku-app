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
actor LibraryImporter {
    private var bank: PuzzleBank
    private let persist: @Sendable (PuzzleBank) throws -> Void

    init(bank: PuzzleBank, persist: @escaping @Sendable (PuzzleBank) throws -> Void) {
        self.bank = bank
        self.persist = persist
    }

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
            // 存盘失败只丢持久化，内存里的题库仍可用
        }
    }
}
