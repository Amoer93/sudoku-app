import Foundation
@testable import SudokuEngine
import XCTest

/// 生成并校验 BuiltinPuzzles.json。
///
/// 重新生成（会写文件，在 Packages/SudokuEngine 下运行）：
/// `GENERATE_BUILTIN_PUZZLES=1 swift test -c release --filter BuiltinPuzzleGenerationTests/testGenerateBuiltinPuzzles`
///
/// 校验文件是否与生成器一致（不写文件）：
/// `VERIFY_BUILTIN_PUZZLES=1 swift test -c release --filter BuiltinPuzzleGenerationTests`
final class BuiltinPuzzleGenerationTests: XCTestCase {
    private let perTierGoal = 30
    /// 每档的目标数量；专家档不收试数题，凑不满 30 题是预期内的。
    private let expertGoal = 30
    /// 最多尝试次数。用次数而不是时间，这样结果和机器快慢无关。
    private let maxAttempts = 30000
    private let baseSeed: UInt64 = 20_260_101
    /// 简单档至少要有这么多给定数。
    private let easyMinimumGivens = 30

    /// 每个难度档用哪些目标给定数去挖题；0 表示挖到极小。
    private let targetGivensByTier: [Difficulty: [Int]] = [
        .easy: [40, 36, 33, 30],
        .medium: [32, 30, 28],
        .hard: [27, 25, 0],
        .expert: [0, 24, 22, 20]
    ]

    /// 一次生成的结果：文本、每档数量、尝试次数。
    private struct GenerationResult {
        let jsonText: String
        let entries: [PuzzleBankEntry]
        let attempts: Int
    }

    func testGenerateBuiltinPuzzles() throws {
        guard ProcessInfo.processInfo.environment["GENERATE_BUILTIN_PUZZLES"] == "1" else {
            throw XCTSkip("set GENERATE_BUILTIN_PUZZLES=1 to regenerate BuiltinPuzzles.json")
        }
        let result = try generateBuiltinPuzzles()
        try result.jsonText.write(to: bundledJSONURL(), atomically: true, encoding: .utf8)
        print("GEN wrote \(result.entries.count) entries, attempts=\(result.attempts)")
    }

    func testCommittedFileMatchesGenerator() throws {
        guard ProcessInfo.processInfo.environment["VERIFY_BUILTIN_PUZZLES"] == "1" else {
            throw XCTSkip("set VERIFY_BUILTIN_PUZZLES=1 to verify BuiltinPuzzles.json against the generator")
        }
        let result = try generateBuiltinPuzzles()
        let committed = try String(contentsOf: bundledJSONURL(), encoding: .utf8)
        XCTAssertEqual(result.jsonText, committed)
    }

    /// 纯函数式生成：只由固定种子和尝试次数上限决定，不读时钟、不写文件。
    private func generateBuiltinPuzzles() throws -> GenerationResult {
        var entriesByTier: [Difficulty: [String: PuzzleBankEntry]] = [:]
        var attempts = 0
        while attempts < maxAttempts {
            let needed = Difficulty.allCases.filter { entriesByTier[$0, default: [:]].count < goal(for: $0) }
            if needed.isEmpty { break }
            // 轮流为还缺题的档位出题，避免一档占满尝试次数
            let tier = needed[attempts % needed.count]
            let targets = targetGivensByTier[tier] ?? [0]
            let target = targets[(attempts / needed.count) % targets.count]
            var generator = PuzzleRandomGenerator(seed: baseSeed &+ UInt64(attempts))
            attempts += 1
            let puzzle = PuzzleGenerator.makePuzzle(targetGivens: target, using: &generator)
            guard let entry = makeEntry(puzzle) else { continue }
            if entriesByTier[entry.difficulty, default: [:]].count < goal(for: entry.difficulty) {
                entriesByTier[entry.difficulty, default: [:]][entry.id.value] = entry
            }
            if attempts % 500 == 0 { report(entriesByTier, attempts: attempts) }
        }
        report(entriesByTier, attempts: attempts)
        let sorted = sortedEntries(entriesByTier)
        return GenerationResult(jsonText: try makeJSONText(sorted), entries: sorted, attempts: attempts)
    }

    private func goal(for tier: Difficulty) -> Int {
        tier == .expert ? expertGoal : perTierGoal
    }

    private func report(_ entriesByTier: [Difficulty: [String: PuzzleBankEntry]], attempts: Int) {
        let counts = Difficulty.allCases.map { "\($0)=\(entriesByTier[$0, default: [:]].count)" }
        print("GEN attempts=\(attempts) \(counts.joined(separator: " "))")
    }

    /// 评分并筛选；不符合入库条件的题返回 nil。
    private func makeEntry(_ puzzle: Grid) -> PuzzleBankEntry? {
        guard case .success(let grade) = DifficultyGrader.grade(puzzle, rules: .nineByNine) else { return nil }
        let givenCount = puzzle.cells.filter { $0 != Grid.emptyCell }.count
        // 简单档给定数太少会显得不像"简单"
        if grade.difficulty == .easy && givenCount < easyMinimumGivens { return nil }
        // 内置专家题必须能用逻辑技巧解出，不收需要试数的题
        if grade.difficulty == .expert && grade.hardestTechnique == .trialAndError { return nil }
        return PuzzleBankEntry(
            id: PuzzleCanonicalizer.fingerprint(puzzle, rules: .nineByNine),
            size: 9,
            givens: puzzle.cells,
            difficulty: grade.difficulty,
            seRating: grade.seRating,
            score: grade.score,
            source: .builtin,
            // 固定时间，保证每次生成的文件完全一致
            addedAt: Date(timeIntervalSince1970: 0)
        )
    }

    /// 按档位、再按指纹排序。
    private func sortedEntries(_ entriesByTier: [Difficulty: [String: PuzzleBankEntry]]) -> [PuzzleBankEntry] {
        var sorted: [PuzzleBankEntry] = []
        for tier in Difficulty.allCases {
            let tierEntries = entriesByTier[tier, default: [:]].values.sorted { $0.id.value < $1.id.value }
            sorted.append(contentsOf: tierEntries)
        }
        return sorted
    }

    /// 每个条目占一行，方便看 diff。
    private func makeJSONText(_ entries: [PuzzleBankEntry]) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        var lines: [String] = []
        for entry in entries {
            let data = try encoder.encode(entry)
            lines.append(String(decoding: data, as: UTF8.self))
        }
        return "[\n" + lines.joined(separator: ",\n") + "\n]\n"
    }

    private func bundledJSONURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SudokuEngine/Resources/BuiltinPuzzles.json")
    }
}
