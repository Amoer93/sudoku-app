import Foundation
@testable import SudokuApp
import SudokuEngine
import XCTest

@MainActor
final class PuzzleProgressCompletionTests: XCTestCase {
    private var folder: URL!
    private var fileURL: URL { folder.appendingPathComponent("records.json") }

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-completion-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
        super.tearDown()
    }

    private func fingerprint(_ text: String) -> PuzzleFingerprint {
        PuzzleFingerprint(value: text)
    }

    private func makeEntry(id: String) -> PuzzleBankEntry {
        PuzzleBankEntry(
            id: fingerprint(id), size: 9, givens: [Int](repeating: 0, count: 81),
            difficulty: .easy, seRating: 1.0, score: 1, source: .builtin,
            addedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func makeModel() -> PuzzleProgressModel {
        PuzzleProgressModel(store: PuzzleProgressStore(fileURL: fileURL))
    }

    func testVersionOneFileWithoutNewFieldsStillLoads() throws {
        // 和第一版 App 写出来的文件一样：没有 completionCount，也没有 size
        let text = """
        {"schemaVersion":1,
         "completed":[{"id":"abc","completedAt":1700000000000}],
         "lastPlayed":{"id":"def","difficulty":2,"playedAt":1700000100000}}
        """
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: fileURL)

        let loaded = PuzzleProgressStore(fileURL: fileURL).load()
        XCTAssertFalse(loaded.isReadOnly)
        XCTAssertEqual(loaded.records.completed.count, 1)
        XCTAssertEqual(loaded.records.completed[0].id, fingerprint("abc"))
        XCTAssertEqual(loaded.records.completed[0].completionCount, 1)
        XCTAssertEqual(loaded.records.lastPlayed?.id, fingerprint("def"))
        XCTAssertEqual(loaded.records.lastPlayed?.difficulty, .hard)
        XCTAssertNil(loaded.records.lastPlayed?.size)
        XCTAssertEqual(loaded.records.schemaVersion, 1)
    }

    func testCompletionCountIsAlwaysWritten() throws {
        let record = CompletedRecord(id: fingerprint("a"), completedAt: Date(timeIntervalSince1970: 1))
        let json = try encodedObject(record)
        XCTAssertEqual(json["completionCount"] as? Int, 1)
    }

    func testDifficultyRawValuesArePinned() throws {
        XCTAssertEqual(Difficulty.easy.rawValue, 0)
        XCTAssertEqual(Difficulty.medium.rawValue, 1)
        XCTAssertEqual(Difficulty.hard.rawValue, 2)
        XCTAssertEqual(Difficulty.expert.rawValue, 3)
        XCTAssertEqual(Difficulty.allCases.count, 4)

        for (difficulty, expected) in [(Difficulty.easy, 0), (.medium, 1), (.hard, 2), (.expert, 3)] {
            let record = LastPlayedRecord(id: fingerprint("x"), difficulty: difficulty, playedAt: Date())
            let json = try encodedObject(record)
            XCTAssertEqual(json["difficulty"] as? Int, expected)
        }
    }

    func testFixtureLastPlayedNeedsNoDifficulty() throws {
        let record = LastPlayedRecord(id: fingerprint("fixture-4"), size: 4, playedAt: Date(timeIntervalSince1970: 3))
        let json = try encodedObject(record)
        XCTAssertNil(json["difficulty"])
        XCTAssertEqual(json["size"] as? Int, 4)
    }

    func testRepeatCompletionRaisesCountsButNotDistinctCount() {
        let model = makeModel()
        let firstDate = Date(timeIntervalSince1970: 100)
        model.markCompleted(id: fingerprint("a"), at: firstDate)
        model.markCompleted(id: fingerprint("a"), at: Date(timeIntervalSince1970: 200))
        model.markCompleted(id: fingerprint("fixture-4"))

        XCTAssertEqual(model.records.completed.count, 2)
        XCTAssertEqual(model.records.completed[0].completionCount, 2)
        XCTAssertEqual(model.records.completed[0].completedAt, firstDate)
        XCTAssertEqual(model.totalCompletions, 3)
        XCTAssertEqual(model.completedCount(in: [makeEntry(id: "a"), makeEntry(id: "b")]), 1)

        let reloaded = PuzzleProgressStore(fileURL: fileURL).load().records
        XCTAssertEqual(reloaded.completed[0].completionCount, 2)
    }

    func testSetLastPlayedKeepsFixtureWithoutDifficulty() {
        let model = makeModel()
        model.setLastPlayed(id: fingerprint("fixture-5"), size: 5)
        XCTAssertNil(model.lastPlayed?.difficulty)
        XCTAssertEqual(model.lastPlayed?.size, 5)
    }

    func testIdentityRules() {
        let entry = makeEntry(id: "bank")
        let bank = ProgressPuzzleIdentity(bankEntry: entry, preset: .nine, isCustomPuzzle: true)
        XCTAssertEqual(bank?.id, fingerprint("bank"))
        XCTAssertEqual(bank?.difficulty, .easy)

        let four = ProgressPuzzleIdentity(bankEntry: nil, preset: .four, isCustomPuzzle: false)
        XCTAssertEqual(four?.id, fingerprint("fixture-4"))
        XCTAssertNil(four?.difficulty)
        XCTAssertEqual(four?.size, 4)
        XCTAssertEqual(
            ProgressPuzzleIdentity(bankEntry: nil, preset: .five, isCustomPuzzle: false)?.id,
            fingerprint("fixture-5")
        )

        XCTAssertNil(ProgressPuzzleIdentity(bankEntry: nil, preset: .nine, isCustomPuzzle: false))
        // 拍照导入的 4×4 不能当成固定题
        XCTAssertNil(ProgressPuzzleIdentity(bankEntry: nil, preset: .four, isCustomPuzzle: true))
    }

    private func encodedObject<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
