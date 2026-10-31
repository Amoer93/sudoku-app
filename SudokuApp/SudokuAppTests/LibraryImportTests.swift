@testable import SudokuApp
import struct SudokuEngine.PuzzleBank
import struct SudokuEngine.PuzzleBankEntry
import struct SudokuEngine.PuzzleFingerprint
import XCTest

/// 测题库存盘，以及拍照导入入库后的提示和存盘时机。
@MainActor
final class LibraryImportTests: XCTestCase {
    /// 数存盘次数；persist 在 actor 里跑，所以要线程安全。
    private final class SaveCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        func increment() {
            lock.lock()
            value += 1
            lock.unlock()
        }
    }

    private var tempFile: URL!

    override func setUp() {
        super.setUp()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        tempFile = folder.appendingPathComponent("PuzzleBank/user-entries.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempFile.deletingLastPathComponent().deletingLastPathComponent())
        super.tearDown()
    }

    /// 一道真实的唯一解 9×9 题。
    private var nineGrid: Grid {
        FixtureLibrary.puzzle(for: .nine).givens
    }

    /// 把每个数字 d 换成 10-d，是同一道题换了个写法。
    private func relabeled(_ grid: Grid) throws -> Grid {
        let cells = grid.cells.map { $0 == Grid.emptyCell ? $0 : 10 - $0 }
        return try Grid(size: 9, cells: cells)
    }

    /// 造一个只有指定格子有数字的 9×9 盘面。
    private func grid(with cells: [Int: Int]) throws -> Grid {
        var values = [Int](repeating: Grid.emptyCell, count: 81)
        for (index, digit) in cells {
            values[index] = digit
        }
        return try Grid(size: 9, cells: values)
    }

    private func makeImporter(counter: SaveCounter = SaveCounter()) -> LibraryImporter {
        let store = PuzzleBankStore(fileURL: tempFile)
        return LibraryImporter(bank: store.load()) { bank in
            counter.increment()
            try store.save(bank)
        }
    }

    func testStoreRoundTripKeepsUserEntries() throws {
        let store = PuzzleBankStore(fileURL: tempFile)
        let entry = PuzzleBankEntry(
            id: PuzzleFingerprint(value: "test-user-entry"), size: 9, givens: nineGrid.cells,
            difficulty: .hard, seRating: 3.0, score: 10, source: .userUpload,
            addedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        var bank = store.load()
        let builtinCount = bank.entries.count
        bank = PuzzleBank(entries: bank.entries + [entry])
        try store.save(bank)
        let reloaded = store.load()
        XCTAssertEqual(reloaded.entries(source: .userUpload), [entry])
        XCTAssertEqual(reloaded.entries(source: .builtin).count, builtinCount)
    }

    func testCorruptFileIsMovedAsideAndBuiltinLoads() throws {
        let folder = tempFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let garbage = Data("not json".utf8)
        try garbage.write(to: tempFile)
        let bank = PuzzleBankStore(fileURL: tempFile).load()
        XCTAssertEqual(bank.entries(source: .userUpload).count, 0)
        XCTAssertEqual(bank.entries.count, try PuzzleBank.load(userData: nil).entries.count)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        let aside = try XCTUnwrap(names.first { $0.hasPrefix("user-entries.corrupt-") && $0.hasSuffix(".json") })
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(aside)), garbage)
    }

    func testSuccessPersistsOnce() async throws {
        let counter = SaveCounter()
        let notice = await makeImporter(counter: counter).add(nineGrid, rules: .nineByNine)
        XCTAssertTrue(notice.text.hasPrefix("已加入题库："))
        XCTAssertNil(notice.existingEntry)
        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(PuzzleBankStore(fileURL: tempFile).load().entries(source: .userUpload).count, 1)
    }

    func testDuplicateAndRelabeledAreNotSavedAgain() async throws {
        let counter = SaveCounter()
        let importer = makeImporter(counter: counter)
        _ = await importer.add(nineGrid, rules: .nineByNine)
        let same = await importer.add(nineGrid, rules: .nineByNine)
        let relabelled = await importer.add(try relabeled(nineGrid), rules: .nineByNine)
        for second in [same, relabelled] {
            XCTAssertEqual(second.text, ImportBankCopy.duplicate)
            XCTAssertEqual(second.existingEntry?.givens, nineGrid.cells)
        }
        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(PuzzleBankStore(fileURL: tempFile).load().entries(source: .userUpload).count, 1)
    }

    func testNoSolutionIsNotSaved() async throws {
        let counter = SaveCounter()
        let notice = await makeImporter(counter: counter).add(try grid(with: [0: 1, 1: 1]), rules: .nineByNine)
        XCTAssertEqual(notice.text, "题目无解，未入库")
        XCTAssertEqual(counter.count, 0)
    }

    func testMultipleSolutionsAreNotSaved() async throws {
        let counter = SaveCounter()
        let notice = await makeImporter(counter: counter).add(try grid(with: [0: 1, 10: 2, 20: 3]), rules: .nineByNine)
        XCTAssertEqual(notice.text, "题目不唯一，未入库")
        XCTAssertEqual(counter.count, 0)
    }

    func testFourByFourIsNotSaved() async throws {
        let counter = SaveCounter()
        let small = try Grid(size: 4, cells: [1] + Array(repeating: Grid.emptyCell, count: 15))
        let notice = await makeImporter(counter: counter).add(small, rules: .fourByFour)
        XCTAssertEqual(notice.text, LibraryCopy.message(.unsupportedSize))
        XCTAssertEqual(counter.count, 0)
    }
}
