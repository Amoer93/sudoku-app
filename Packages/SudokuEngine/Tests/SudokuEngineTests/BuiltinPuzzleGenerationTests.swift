import Foundation
@testable import SudokuEngine
import XCTest

/// 生成 BuiltinPuzzles.json 的入口。只有设置 GENERATE_BUILTIN_PUZZLES=1 才会运行。
///
/// 用法（在 Packages/SudokuEngine 下）：
/// `GENERATE_BUILTIN_PUZZLES=1 swift test -c release --filter BuiltinPuzzleGenerationTests`
final class BuiltinPuzzleGenerationTests: XCTestCase {
    private let perTierGoal = 30
    private let timeBudgetSeconds: TimeInterval = 480
    private let baseSeed: UInt64 = 20_260_101

    /// 每个难度档用哪些目标给定数去挖题；0 表示挖到极小。
    private let targetGivensByTier: [Difficulty: [Int]] = [
        .easy: [40, 36, 34],
        .medium: [32, 30, 28],
        .hard: [27, 25, 0],
        .expert: [0, 24, 22]
    ]

    func testGenerateBuiltinPuzzles() throws {
        guard ProcessInfo.processInfo.environment["GENERATE_BUILTIN_PUZZLES"] == "1" else {
            throw XCTSkip("set GENERATE_BUILTIN_PUZZLES=1 to regenerate BuiltinPuzzles.json")
        }
        let start = Date()
        var entriesByTier: [Difficulty: [String: PuzzleBankEntry]] = [:]
        var seedOffset: UInt64 = 0
        var attempts = 0
        while Date().timeIntervalSince(start) < timeBudgetSeconds {
            let needed = Difficulty.allCases.filter { entriesByTier[$0, default: [:]].count < perTierGoal }
            if needed.isEmpty { break }
            // 轮流为还缺题的档位出题，避免一档占满时间
            let tier = needed[attempts % needed.count]
            let targets = targetGivensByTier[tier] ?? [0]
            let target = targets[(attempts / needed.count) % targets.count]
            var generator = PuzzleRandomGenerator(seed: baseSeed &+ seedOffset)
            seedOffset += 1
            attempts += 1
            let puzzle = PuzzleGenerator.makePuzzle(targetGivens: target, using: &generator)
            guard let entry = makeEntry(puzzle) else { continue }
            if entriesByTier[entry.difficulty, default: [:]].count < perTierGoal {
                entriesByTier[entry.difficulty, default: [:]][entry.id.value] = entry
            }
            if attempts % 100 == 0 { report(entriesByTier, attempts: attempts, start: start) }
        }
        report(entriesByTier, attempts: attempts, start: start)
        try write(entriesByTier)
    }

    private func report(_ entriesByTier: [Difficulty: [String: PuzzleBankEntry]], attempts: Int, start: Date) {
        let counts = Difficulty.allCases.map { "\($0)=\(entriesByTier[$0, default: [:]].count)" }
        let elapsed = Int(Date().timeIntervalSince(start))
        print("GEN attempts=\(attempts) elapsed=\(elapsed)s \(counts.joined(separator: " "))")
    }

    private func makeEntry(_ puzzle: Grid) -> PuzzleBankEntry? {
        guard case .success(let grade) = DifficultyGrader.grade(puzzle, rules: .nineByNine) else { return nil }
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

    /// 按档位、再按指纹排序后写文件；每个条目占一行，方便看 diff。
    private func write(_ entriesByTier: [Difficulty: [String: PuzzleBankEntry]]) throws {
        var sorted: [PuzzleBankEntry] = []
        for tier in Difficulty.allCases {
            let tierEntries = entriesByTier[tier, default: [:]].values.sorted { $0.id.value < $1.id.value }
            sorted.append(contentsOf: tierEntries)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = .sortedKeys
        var lines: [String] = []
        for entry in sorted {
            let data = try encoder.encode(entry)
            lines.append(String(decoding: data, as: UTF8.self))
        }
        let text = "[\n" + lines.joined(separator: ",\n") + "\n]\n"
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/SudokuEngine/Resources/BuiltinPuzzles.json")
        try text.write(to: url, atomically: true, encoding: .utf8)
        print("GEN wrote \(sorted.count) entries to \(url.path)")
    }
}
