import SudokuEngine
import XCTest

final class DifficultyTypesTests: XCTestCase {
    // 分档边界：easy ≤ 2.3，medium ≤ 3.4，hard ≤ 4.4，其余 expert
    func testSERatingMappingBoundaries() {
        XCTAssertEqual(Difficulty.difficulty(forSERating: 1.2), .easy)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 2.3), .easy)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 2.4), .medium)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 3.4), .medium)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 3.5), .hard)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 4.4), .hard)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 4.5), .expert)
        XCTAssertEqual(Difficulty.difficulty(forSERating: 11.0), .expert)
    }

    // 技巧难度由 SE 值推出，和原先手工分档不同的几项要锁住
    func testTechniqueDifficultyBySEValue() {
        XCTAssertEqual(Technique.hiddenSingle.difficulty, .easy)
        XCTAssertEqual(Technique.nakedSingle.difficulty, .easy)
        XCTAssertEqual(Technique.pointing.difficulty, .medium)
        XCTAssertEqual(Technique.xWing.difficulty, .medium)
        XCTAssertEqual(Technique.hiddenPair.difficulty, .medium)
        XCTAssertEqual(Technique.nakedTriple.difficulty, .hard)
        XCTAssertEqual(Technique.xyWing.difficulty, .hard)
        XCTAssertEqual(Technique.nakedQuad.difficulty, .expert)
        XCTAssertEqual(Technique.hiddenQuad.difficulty, .expert)
        XCTAssertEqual(Technique.chain.difficulty, .expert)
        XCTAssertEqual(Technique.trialAndError.difficulty, .expert)
    }

    // 枚举顺序和 SE 值都按约定，原始值决定 Codable 和排序
    func testOrderingAndWeights() {
        XCTAssertLessThan(Difficulty.easy, Difficulty.expert)
        XCTAssertLessThan(Technique.nakedSingle, Technique.trialAndError)
        XCTAssertEqual(Technique.allCases.count, 15)
        XCTAssertEqual(Technique.xWing.weight, 32)
        XCTAssertEqual(Technique.trialAndError.weight, 110)
    }

    func testGradeResultCodableRoundTrip() throws {
        let original = GradeResult(
            difficulty: .medium, score: 120, seRating: 2.8,
            hardestTechnique: .boxLineReduction, techniqueCounts: [.nakedSingle: 30, .boxLineReduction: 1]
        )
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(GradeResult.self, from: data), original)
    }
}
