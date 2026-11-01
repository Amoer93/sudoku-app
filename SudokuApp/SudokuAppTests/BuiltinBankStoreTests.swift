@testable import SudokuApp
import enum SudokuEngine.Difficulty
import enum SudokuEngine.DifficultyGrader
import struct SudokuEngine.Grid
import struct SudokuEngine.PuzzleBankEntry
import struct SudokuEngine.Rules
import enum SudokuEngine.Technique
import XCTest

/// Checks the real built-in puzzles loaded through PuzzleBankStore.
final class BuiltinBankStoreTests: XCTestCase {
    func test_builtinEntriesAreHealthy() throws {
        // 用不存在的文件路径，保证只读到内置题，不受本机用户数据影响
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-dir-\(UUID().uuidString)/user-entries.json")
        let bank = PuzzleBankStore(fileURL: missingFile).load()
        let builtins = bank.entries.filter { $0.source == .builtin }

        // 不写死总数，只要求非空
        XCTAssertGreaterThan(builtins.count, 0)

        // 每个难度档至少有一道内置题
        for difficulty in SudokuEngine.Difficulty.allCases {
            let countForLevel = builtins.filter { $0.difficulty == difficulty }.count
            XCTAssertGreaterThan(countForLevel, 0, "no built-in puzzle for \(difficulty)")
        }

        // id 不能重复
        let uniqueIds = Set(builtins.map { $0.id })
        XCTAssertEqual(uniqueIds.count, builtins.count, "duplicate built-in ids")

        // 内置题不应该需要试错才能解
        for entry in builtins {
            let grid = try SudokuEngine.Grid(size: entry.size, cells: entry.givens)
            let result = SudokuEngine.DifficultyGrader.grade(grid, rules: SudokuEngine.Rules.nineByNine)
            switch result {
            case .success(let grade):
                XCTAssertNotEqual(
                    grade.hardestTechnique,
                    SudokuEngine.Technique.trialAndError,
                    "built-in puzzle \(entry.id) needs trial and error"
                )
            case .failure(let error):
                XCTFail("built-in puzzle \(entry.id) cannot be graded: \(error)")
            }
        }
    }
}
