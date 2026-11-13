@testable import SudokuApp
import SudokuEngine
import XCTest

/// 存档快照：JSON 往返、恢复后行为不变、坏存档一律拒绝。
@MainActor
final class BoardSessionStateTests: XCTestCase {
    private let puzzle = FixtureLibrary.puzzle(for: .four)
    private let puzzleID = PuzzleFingerprint(value: "fixture-4")
    private let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

    func testJSONRoundTripKeepsEverything() throws {
        let session = try makeSession()
        XCTAssertEqual(session.layers.count, 2)
        XCTAssertEqual(session.undoStack.count, 2)
        XCTAssertEqual(session.redoStack.count, 1)
        XCTAssertTrue(session.usedAutoSolve)
        XCTAssertTrue(session.hasRecordedCompletion)
        let data = try XCTUnwrap(session.encoded())
        XCTAssertEqual(BoardSessionState.decode(from: data), session)
    }

    func testEmptySnapshotRoundTrips() throws {
        let session = try XCTUnwrap(snapshot(of: makeModel()))
        let loaded = try XCTUnwrap(BoardSessionState.decode(from: try XCTUnwrap(session.encoded())))
        XCTAssertTrue(loaded.layers.isEmpty && loaded.undoStack.isEmpty && loaded.redoStack.isEmpty)
        XCTAssertNotNil(restore(loaded))
    }

    func testRestoreThenUndoRedoRollbackMatchOriginal() throws {
        let original = makeBusyModel()
        let session = try XCTUnwrap(original.makeSessionState(puzzleID: puzzleID, savedAt: savedAt))
        let restored = try XCTUnwrap(restore(session))
        XCTAssertEqual(restored.grid, original.grid)
        XCTAssertEqual(restored.cellDepths, original.cellDepths)
        XCTAssertEqual(restored.layers.count, 2)
        XCTAssertTrue(restored.usedAutoSolve)
        XCTAssertTrue(restored.hasRecordedCompletion)
        XCTAssertNil(restored.selectedIndex)
        XCTAssertEqual(restored.notice, .idle)
        XCTAssertEqual(snapshot(of: restored), snapshot(of: original))

        let steps: [(BoardViewModel) -> Void] = [
            { $0.redo() }, { $0.undo() }, { $0.undo() }, { $0.rollbackLayer() }, { $0.rollbackLayer() }
        ]
        for step in steps {
            step(original)
            step(restored)
            XCTAssertEqual(snapshot(of: restored), snapshot(of: original))
        }
    }

    func testRejectsInvalidSnapshots() throws {
        let base = try makeSession()
        XCTAssertNotNil(restore(base))
        let cases: [(String, (inout BoardSessionState) -> Void)] = [
            ("short grid", { $0.grid = String($0.grid.dropLast()) }),
            ("long depths", { $0.depths += "0" }),
            ("value out of range", { $0.grid = Self.replacing($0.grid, at: 3, with: "5") }),
            ("given changed", { $0.grid = Self.replacing($0.grid, at: 0, with: "2") }),
            ("given changed in undo", {
                $0.undoStack[0].grid = Self.replacing($0.undoStack[0].grid, at: 0, with: "0")
            }),
            ("depth above layer count", { $0.depths = Self.replacing($0.depths, at: 3, with: "3") }),
            ("depth above nine", { $0.depths = Self.replacing($0.depths, at: 3, with: "a") }),
            ("undoCount too large", { $0.layers[0].undoCount = $0.undoStack.count + 1 }),
            ("undoCount decreasing", { $0.layers[1].undoCount = 0 }),
            ("size mismatch", { $0.size = 5 }),
            ("schema 0", { $0.schemaVersion = 0 })
        ]
        for (name, mutate) in cases {
            var broken = base
            mutate(&broken)
            XCTAssertNil(restore(broken), name)
        }
    }

    func testDifferentPuzzleIDIsRejected() throws {
        XCTAssertNil(restore(try makeSession(), as: PuzzleFingerprint(value: "other-puzzle")))
    }

    func testUndecodableJSONIsNoSave() throws {
        XCTAssertNil(BoardSessionState.decode(from: Data("not json".utf8)))
        XCTAssertNil(BoardSessionState.decode(from: Data("{}".utf8)))
        // 缺 schemaVersion 也算没有存档
        let noVersion = #"{"puzzleID":"fixture-4","size":4,"grid":"0000000000000000","depths":"0000000000000000"}"#
        XCTAssertNil(BoardSessionState.decode(from: Data(noVersion.utf8)))
        var object = try jsonObject(of: makeSession())
        object["schemaVersion"] = 2
        let loaded = BoardSessionState.decode(from: try JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(loaded.flatMap { restore($0) })
    }

    func testUnknownKeyIgnoredAndMissingCompletionDefaultsToFalse() throws {
        var object = try jsonObject(of: makeSession())
        object["futureField"] = ["a": 1]
        object.removeValue(forKey: "hasRecordedCompletion")
        let data = try JSONSerialization.data(withJSONObject: object)
        let loaded = try XCTUnwrap(BoardSessionState.decode(from: data))
        XCTAssertFalse(loaded.hasRecordedCompletion)
        XCTAssertNotNil(restore(loaded))
    }

    // MARK: - 辅助

    private func makeModel() -> BoardViewModel {
        BoardViewModel(title: "4×4", puzzle: puzzle, engine: FixtureBoardEngine())
    }

    /// 有两层假设、两步撤销、一步重做的盘面。
    private func makeBusyModel() -> BoardViewModel {
        let model = makeModel()
        fill(model, index: 3, value: 4)
        model.startLayer()
        fill(model, index: 5, value: 4)
        model.startLayer()
        fill(model, index: 8, value: 2)
        model.undo()
        model.usedAutoSolve = true
        model.hasRecordedCompletion = true
        return model
    }

    private func makeSession() throws -> BoardSessionState {
        try XCTUnwrap(makeBusyModel().makeSessionState(puzzleID: puzzleID, savedAt: savedAt))
    }

    private func restore(_ session: BoardSessionState, as id: PuzzleFingerprint? = nil) -> BoardViewModel? {
        BoardViewModel.restored(title: "4×4", puzzle: puzzle, session: session, puzzleID: id ?? puzzleID,
                                engine: FixtureBoardEngine())
    }

    private func snapshot(of model: BoardViewModel) -> BoardSessionState? {
        model.makeSessionState(puzzleID: puzzleID, savedAt: savedAt)
    }

    private func jsonObject(of session: BoardSessionState) throws -> [String: Any] {
        let data = try XCTUnwrap(session.encoded())
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func fill(_ model: BoardViewModel, index: Int, value: Int) {
        model.select(index: index)
        model.enter(value)
    }

    private static func replacing(_ text: String, at index: Int, with character: Character) -> String {
        var characters = Array(text)
        characters[index] = character
        return String(characters)
    }
}
