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
    /// 第一阶段里"逻辑专家题"（评分器判专家、但不需要试数）的数量；它们入库时放进困难档。
    private let logicExpertGoal = 30
    /// 第二阶段：需要试数的专家题数量。
    private let trialExpertGoal = 30
    /// 每阶段最多尝试次数。用次数而不是时间，这样结果和机器快慢无关。
    private let maxAttempts = 30000
    private let baseSeed: UInt64 = 20_260_101
    /// 简单档至少要有这么多给定数。
    private let easyMinimumGivens = 30
    /// 试数的 SE 值（见 docs/Difficulty.md）。
    private let trialAndErrorRating = 11.0

    /// 每个难度档用哪些目标给定数去挖题；0 表示挖到极小。
    private let targetGivensByTier: [Difficulty: [Int]] = [
        .easy: [40, 36, 33, 30],
        .medium: [32, 30, 28],
        .hard: [27, 25, 0],
        .expert: [0, 24, 22, 20]
    ]

    /// 一次生成的结果：文本、条目、两阶段合计的尝试次数。
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
    ///
    /// 第一阶段保持原来的轮流出题逻辑，让已有的 120 题不变；第二阶段接着往后用种子，
    /// 只收需要试数的专家题。
    private func generateBuiltinPuzzles() throws -> GenerationResult {
        var gradedByTier: [Difficulty: [String: PuzzleBankEntry]] = [:]
        let firstAttempts = collectLogicPuzzles(into: &gradedByTier)
        var trialEntries: [String: PuzzleBankEntry] = [:]
        let totalAttempts = collectTrialPuzzles(
            into: &trialEntries, existing: gradedByTier, startAttempt: firstAttempts
        )
        var sorted: [PuzzleBankEntry] = []
        sorted.append(contentsOf: sortedByID(gradedByTier[.easy, default: [:]]))
        sorted.append(contentsOf: sortedByID(gradedByTier[.medium, default: [:]]))
        // 困难档 = 评分为困难的题 + 被指定放进困难档的逻辑专家题
        var hardTier = gradedByTier[.hard, default: [:]]
        for (key, entry) in gradedByTier[.expert, default: [:]] {
            hardTier[key] = withHardOverride(entry)
        }
        sorted.append(contentsOf: sortedByID(hardTier))
        sorted.append(contentsOf: sortedByID(trialEntries))
        return GenerationResult(jsonText: try makeJSONText(sorted), entries: sorted, attempts: totalAttempts)
    }

    /// 第一阶段：简单/中等/困难各 30，加 30 道不需要试数的专家题。返回用掉的尝试次数。
    private func collectLogicPuzzles(into entriesByTier: inout [Difficulty: [String: PuzzleBankEntry]]) -> Int {
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
            guard let entry = makeEntry(puzzle, allowTrialAndError: false) else { continue }
            if entriesByTier[entry.difficulty, default: [:]].count < goal(for: entry.difficulty) {
                entriesByTier[entry.difficulty, default: [:]][entry.id.value] = entry
            }
        }
        report("logic", entriesByTier.mapValues(\.count), attempts: attempts)
        return attempts
    }

    /// 第二阶段：只收需要试数的专家题，并和第一阶段的指纹去重。返回累计尝试次数。
    private func collectTrialPuzzles(
        into trialEntries: inout [String: PuzzleBankEntry],
        existing: [Difficulty: [String: PuzzleBankEntry]],
        startAttempt: Int
    ) -> Int {
        var knownIDs = Set<String>()
        for tierEntries in existing.values {
            knownIDs.formUnion(tierEntries.keys)
        }
        let targets = targetGivensByTier[.expert] ?? [0]
        var attempts = startAttempt
        while attempts - startAttempt < maxAttempts && trialEntries.count < trialExpertGoal {
            let target = targets[(attempts - startAttempt) % targets.count]
            var generator = PuzzleRandomGenerator(seed: baseSeed &+ UInt64(attempts))
            attempts += 1
            let puzzle = PuzzleGenerator.makePuzzle(targetGivens: target, using: &generator)
            guard let entry = makeEntry(puzzle, allowTrialAndError: true) else { continue }
            guard entry.difficulty == .expert, entry.seRating == trialAndErrorRating else { continue }
            if knownIDs.insert(entry.id.value).inserted {
                trialEntries[entry.id.value] = entry
            }
        }
        report("trial", [.expert: trialEntries.count], attempts: attempts - startAttempt)
        return attempts
    }

    private func goal(for tier: Difficulty) -> Int {
        tier == .expert ? logicExpertGoal : perTierGoal
    }

    private func report(_ phase: String, _ counts: [Difficulty: Int], attempts: Int) {
        let text = Difficulty.allCases.map { "\($0)=\(counts[$0, default: 0])" }
        print("GEN \(phase) attempts=\(attempts) \(text.joined(separator: " "))")
    }

    /// 评分并筛选；不符合入库条件的题返回 nil。
    private func makeEntry(_ puzzle: Grid, allowTrialAndError: Bool) -> PuzzleBankEntry? {
        guard case .success(let grade) = DifficultyGrader.grade(puzzle, rules: .nineByNine) else { return nil }
        let givenCount = puzzle.cells.filter { $0 != Grid.emptyCell }.count
        // 简单档给定数太少会显得不像"简单"
        if grade.difficulty == .easy && givenCount < easyMinimumGivens { return nil }
        // 第一阶段不收需要试数的题；第二阶段才收
        if !allowTrialAndError && grade.hardestTechnique == .trialAndError { return nil }
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

    /// 把评分为专家的逻辑题放进困难档，并记录覆盖。
    private func withHardOverride(_ entry: PuzzleBankEntry) -> PuzzleBankEntry {
        PuzzleBankEntry(
            id: entry.id, size: entry.size, givens: entry.givens, difficulty: entry.difficulty,
            seRating: entry.seRating, score: entry.score, source: .builtin, addedAt: entry.addedAt,
            tierOverride: .hard
        )
    }

    /// 按指纹排序，保证输出顺序固定。
    private func sortedByID(_ entries: [String: PuzzleBankEntry]) -> [PuzzleBankEntry] {
        entries.values.sorted { $0.id.value < $1.id.value }
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
