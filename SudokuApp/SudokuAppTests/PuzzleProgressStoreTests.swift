import Foundation
@testable import SudokuApp
import SudokuEngine
import XCTest

@MainActor
final class PuzzleProgressStoreTests: XCTestCase {
    private var folder: URL!
    private var fileURL: URL { folder.appendingPathComponent("records.json") }

    override func setUp() {
        super.setUp()
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("progress-tests-\(UUID().uuidString)")
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

    private func writeRaw(_ text: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: fileURL)
    }

    private func corruptFiles() throws -> [String] {
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        return names.filter { $0.hasPrefix("records.corrupt-") }
    }

    func testRoundTripKeepsCompletedAndLastPlayed() throws {
        let store = PuzzleProgressStore(fileURL: fileURL)
        var records = PuzzleProgressRecords()
        // 用整毫秒，避免浮点误差影响比较
        records.completed = [
            CompletedRecord(id: fingerprint("a"), completedAt: Date(timeIntervalSince1970: 1_700_000_000.123))
        ]
        records.lastPlayed = LastPlayedRecord(
            id: fingerprint("b"), difficulty: .hard, playedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        try store.save(records)

        let loaded = PuzzleProgressStore(fileURL: fileURL).load()
        XCTAssertFalse(loaded.isReadOnly)
        XCTAssertEqual(loaded.records.completed.count, 1)
        XCTAssertEqual(loaded.records.completed[0].id, fingerprint("a"))
        XCTAssertEqual(
            loaded.records.completed[0].completedAt.timeIntervalSince1970, 1_700_000_000.123, accuracy: 0.001
        )
        XCTAssertEqual(loaded.records.lastPlayed, records.lastPlayed)
    }

    func testMissingFileGivesEmptyRecords() {
        let loaded = PuzzleProgressStore(fileURL: fileURL).load()
        XCTAssertEqual(loaded.records, PuzzleProgressRecords())
        XCTAssertFalse(loaded.isReadOnly)
    }

    func testCorruptFileIsMovedAsideAndNotClobbered() throws {
        try writeRaw("not json")
        let store = PuzzleProgressStore(fileURL: fileURL)
        let loaded = store.load()
        XCTAssertEqual(loaded.records, PuzzleProgressRecords())
        XCTAssertFalse(loaded.isReadOnly)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let sidecars = try corruptFiles()
        XCTAssertEqual(sidecars.count, 1)

        var fresh = PuzzleProgressRecords()
        fresh.completed = [CompletedRecord(id: fingerprint("a"), completedAt: Date(timeIntervalSince1970: 5))]
        try store.save(fresh)
        XCTAssertEqual(PuzzleProgressStore(fileURL: fileURL).load().records, fresh)
        let sidecar = folder.appendingPathComponent(sidecars[0])
        XCTAssertEqual(try String(contentsOf: sidecar, encoding: .utf8), "not json")
    }

    func testNewerSchemaIsReadOnlyAndFileUntouched() throws {
        let original = "{\"schemaVersion\":2,\"completed\":[],\"future\":true}"
        try writeRaw(original)
        let store = PuzzleProgressStore(fileURL: fileURL)
        let loaded = store.load()
        XCTAssertEqual(loaded.records, PuzzleProgressRecords())
        XCTAssertTrue(loaded.isReadOnly)

        var records = PuzzleProgressRecords()
        records.completed = [CompletedRecord(id: fingerprint("x"), completedAt: Date())]
        XCTAssertNoThrow(try store.save(records))

        let model = PuzzleProgressModel(store: store)
        XCTAssertTrue(model.isReadOnly)
        model.markCompleted(id: fingerprint("y"))
        model.setLastPlayed(id: fingerprint("y"), difficulty: .easy)

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), original)
        XCTAssertTrue(try corruptFiles().isEmpty)
    }

    func testMarkCompletedTwiceDoesNotDoubleCount() {
        let model = PuzzleProgressModel(store: PuzzleProgressStore(fileURL: fileURL))
        let firstDate = Date(timeIntervalSince1970: 100)
        model.markCompleted(id: fingerprint("a"), at: firstDate)
        model.markCompleted(id: fingerprint("a"), at: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(model.records.completed.count, 1)
        XCTAssertEqual(model.records.completed[0].completedAt, firstDate)
        XCTAssertEqual(PuzzleProgressStore(fileURL: fileURL).load().records.completed.count, 1)
    }

    func testCompletedCountOnlyCountsPresentEntries() {
        let model = PuzzleProgressModel(store: PuzzleProgressStore(fileURL: fileURL))
        model.markCompleted(id: fingerprint("a"))
        model.markCompleted(id: fingerprint("gone"))
        let entries = [makeEntry(id: "a"), makeEntry(id: "a"), makeEntry(id: "b")]
        XCTAssertEqual(model.completedCount(in: entries), 1)
    }
}
