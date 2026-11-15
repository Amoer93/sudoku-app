import Foundation
@testable import SudokuEngine
import XCTest

/// 生成并校验 SmallBuiltinPuzzles.json（4×4、5×5 内置题）。运行命令见 docs/Difficulty.md。
final class SmallBuiltinPuzzleGenerationTests: XCTestCase {
    private struct ShortSetError: Error {}

    private let perTierGoal = 20
    /// 每个边长最多尝试次数。用次数而不是时间，这样结果和机器快慢无关。
    private let maxAttempts = 5000
    private let baseSeed: UInt64 = 20_261_115
    /// 每个边长轮流使用的目标给定数，两档都要覆盖到。
    private let plans: [(rules: Rules, targets: [Int])] = [
        (.fourByFour, [9, 10, 8, 5, 4, 6]),
        (.fiveByFive, [13, 14, 12, 8, 7, 9])
    ]

    func testGenerateSmallBuiltinPuzzles() throws {
        guard ProcessInfo.processInfo.environment["GENERATE_SMALL_BUILTIN_PUZZLES"] == "1" else {
            throw XCTSkip("set GENERATE_SMALL_BUILTIN_PUZZLES=1 to regenerate SmallBuiltinPuzzles.json")
        }
        try generateJSONText().write(to: bundledJSONURL(), atomically: true, encoding: .utf8)
    }

    func testCommittedSmallFileMatchesGenerator() throws {
        guard ProcessInfo.processInfo.environment["VERIFY_BUILTIN_PUZZLES"] == "1" else {
            throw XCTSkip("set VERIFY_BUILTIN_PUZZLES=1 to verify SmallBuiltinPuzzles.json against the generator")
        }
        let committed = try String(contentsOf: bundledJSONURL(), encoding: .utf8)
        XCTAssertEqual(try generateJSONText(), committed)
    }

    /// 纯函数式生成：只由固定种子和尝试次数上限决定。每个条目占一行，方便看 diff。
    private func generateJSONText() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        var lines: [String] = []
        for plan in plans {
            for entry in try collectEntries(rules: plan.rules, targets: plan.targets) {
                lines.append(String(decoding: try encoder.encode(entry), as: UTF8.self))
            }
        }
        return "[\n" + lines.joined(separator: ",\n") + "\n]\n"
    }

    /// 为一个边长凑齐简单、困难各 20 题；凑不齐就报错。返回顺序：简单在前，各自按指纹排序。
    private func collectEntries(rules: Rules, targets: [Int]) throws -> [PuzzleBankEntry] {
        var entriesByTier: [Difficulty: [PuzzleBankEntry]] = [.easy: [], .hard: []]
        var seenIDs = Set<PuzzleFingerprint>()
        var attempts = 0
        while attempts < maxAttempts && entriesByTier.values.contains(where: { $0.count < perTierGoal }) {
            // 每个边长用自己的一段种子，互不影响
            var generator = PuzzleRandomGenerator(seed: baseSeed &+ UInt64(rules.size) << 32 &+ UInt64(attempts))
            let target = targets[attempts % targets.count]
            attempts += 1
            let puzzle = PuzzleGenerator.makePuzzle(rules: rules, targetGivens: target, using: &generator)
            guard let grade = gradeSmallBoard(puzzle, rules: rules),
                  entriesByTier[grade.difficulty, default: []].count < perTierGoal else { continue }
            let fingerprint = smallFingerprint(puzzle, rules: rules)
            guard seenIDs.insert(fingerprint).inserted else { continue }
            entriesByTier[grade.difficulty, default: []].append(PuzzleBankEntry(
                id: fingerprint, size: rules.size, givens: puzzle.cells, difficulty: grade.difficulty,
                seRating: grade.rating.seRating, score: grade.rating.score, source: .builtin,
                // 固定时间，保证每次生成的文件完全一致
                addedAt: Date(timeIntervalSince1970: 0)
            ))
        }
        let easy = entriesByTier[.easy, default: []].sorted { $0.id.value < $1.id.value }
        let hard = entriesByTier[.hard, default: []].sorted { $0.id.value < $1.id.value }
        print("GEN small size=\(rules.size) attempts=\(attempts) easy=\(easy.count) hard=\(hard.count)")
        guard easy.count == perTierGoal, hard.count == perTierGoal else {
            XCTFail("size \(rules.size) is short: easy=\(easy.count) hard=\(hard.count)")
            throw ShortSetError()
        }
        return easy + hard
    }

    private func bundledJSONURL() -> URL {
        URL(fileURLWithPath: #filePath + "/../../../Sources/SudokuEngine/Resources/SmallBuiltinPuzzles.json")
            .standardizedFileURL
    }
}
