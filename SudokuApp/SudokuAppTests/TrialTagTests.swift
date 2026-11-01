import Foundation
@testable import SudokuApp
import enum SudokuEngine.Difficulty
import enum SudokuEngine.GradeError
import struct SudokuEngine.GradeResult
import struct SudokuEngine.PuzzleBank
import struct SudokuEngine.PuzzleBankEntry
import struct SudokuEngine.PuzzleFingerprint
import enum SudokuEngine.Technique
import XCTest

/// 线程安全的调用计数，给 @Sendable 的评级闭包用。
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    func record(_ key: String) {
        lock.lock()
        counts[key, default: 0] += 1
        lock.unlock()
    }

    func count(_ key: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[key, default: 0]
    }
}

final class TrialTagTests: XCTestCase {
    private func grade(_ technique: Technique) -> GradeResult {
        GradeResult(
            difficulty: .expert, score: 1, seRating: 1, hardestTechnique: technique,
            techniqueCounts: [technique: 1]
        )
    }

    private func entry(_ name: String) -> PuzzleBankEntry {
        PuzzleBankEntry(
            id: PuzzleFingerprint(value: name), size: 9, givens: Array(repeating: 0, count: 81),
            difficulty: .easy, seRating: 1, score: 1, source: .builtin, addedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testTrialAndErrorNeedsTag() {
        XCTAssertTrue(TrialTagRule.needsTrial(.success(grade(.trialAndError))))
    }

    func testOtherTechniqueDoesNotNeedTag() {
        // 即使是 expert 档，只要最难技巧不是试数就不显示
        XCTAssertFalse(TrialTagRule.needsTrial(.success(grade(.nakedSingle))))
    }

    func testGradeFailureDoesNotNeedTag() {
        XCTAssertFalse(TrialTagRule.needsTrial(.failure(.noSolution)))
        XCTAssertFalse(TrialTagRule.needsTrial(.failure(.multipleSolutions)))
    }

    func testCacheGradesEachIdOnce() async {
        let counter = CallCounter()
        let cache = TrialTagCache { entry in
            counter.record(entry.id.value)
            return entry.id.value == "hard"
        }
        let hard = entry("hard")
        let easy = entry("easy")
        let first = await cache.needsTrial(for: hard)
        let second = await cache.needsTrial(for: hard)
        let other = await cache.needsTrial(for: easy)
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertFalse(other)
        XCTAssertEqual(counter.count("hard"), 1)
        XCTAssertEqual(counter.count("easy"), 1)
    }

    func testConcurrentRequestsShareOneGrading() async {
        let counter = CallCounter()
        let cache = TrialTagCache { entry in
            counter.record(entry.id.value)
            return true
        }
        let target = entry("same")
        async let one = cache.needsTrial(for: target)
        async let two = cache.needsTrial(for: target)
        async let three = cache.needsTrial(for: target)
        _ = await (one, two, three)
        XCTAssertEqual(counter.count("same"), 1)
    }

    func testAccessibilityCopy() {
        XCTAssertEqual(TrialTagCopy.text, "需试错")
        XCTAssertEqual(TrialTagCopy.accessibilityLabel, "需试错：这道题需要假设才能解出")
    }

    func testPickerSubtitleOnlyForExpert() {
        XCTAssertEqual(TrialTagCopy.pickerSubtitle(for: .expert), TrialTagCopy.text)
        for difficulty in Difficulty.allCases where difficulty != .expert {
            XCTAssertNil(TrialTagCopy.pickerSubtitle(for: difficulty))
        }
    }

    @MainActor
    func testViewModelFillsFlagAsynchronously() async {
        let cache = TrialTagCache { _ in true }
        let model = LibraryViewModel(bank: PuzzleBank(), trialCache: cache)
        let target = entry("row")
        XCTAssertFalse(model.needsTrial(target))
        await model.loadTrialFlag(for: target)
        XCTAssertTrue(model.needsTrial(target))
    }
}
