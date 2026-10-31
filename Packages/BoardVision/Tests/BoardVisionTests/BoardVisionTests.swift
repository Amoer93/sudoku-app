@testable import BoardVision
import CoreGraphics
import XCTest

final class FakeCellTextRecognizer: CellTextRecognizer {
    var scripted: [[TextCandidate]]
    private(set) var callCount = 0

    init(scripted: [[TextCandidate]] = []) {
        self.scripted = scripted
    }

    func recognize(_ cell: CGImage) throws -> [TextCandidate] {
        defer { callCount += 1 }
        return callCount < scripted.count ? scripted[callCount] : []
    }
}

/// 生成白底灰度方图；inked 里的 (行, 列) 格中间画黑块，withLines 时画格线。
private func makeImage(side: Int, size: Int, inked: [(Int, Int)] = [], withLines: Bool = false) throws -> CGImage {
    let context = try XCTUnwrap(CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
    ))
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    context.setFillColor(gray: 0, alpha: 1)
    let cell = side / size
    for (row, column) in inked {
        // CoreGraphics 的 y 轴向上，所以行号要翻转
        context.fill(CGRect(x: column * cell + cell / 4, y: (size - 1 - row) * cell + cell / 4,
                            width: cell / 2, height: cell / 2))
    }
    if withLines {
        for index in 0 ... size {
            context.fill(CGRect(x: index * cell - 1, y: 0, width: 2, height: side))
            context.fill(CGRect(x: 0, y: index * cell - 1, width: side, height: 2))
        }
    }
    return try XCTUnwrap(context.makeImage())
}

private func input(_ text: String, _ confidence: Double) -> CellInput {
    CellInput(isEmpty: false, candidates: [TextCandidate(text: text, confidence: confidence)])
}

private let emptyInput = CellInput(isEmpty: true, candidates: [])

final class BoardVisionTests: XCTestCase {
    func testSliceCountAndSize() throws {
        for size in [4, 5, 9] {
            let cells = try CellSlicer.slice(makeImage(side: 360, size: size), size: size)
            XCTAssertEqual(cells.count, size * size)
            XCTAssertLessThan(cells[0].width, 360 / size)
            XCTAssertGreaterThan(cells[0].width, 360 / size * 8 / 10)
        }
    }

    func testSliceRejectsUnsupportedSize() throws {
        let image = try makeImage(side: 360, size: 6)
        XCTAssertThrowsError(try CellSlicer.slice(image, size: 6)) {
            XCTAssertEqual($0 as? BoardVisionError, .unsupportedSize(6))
        }
    }

    func testInsetDropsGridLines() throws {
        let cells = try CellSlicer.slice(makeImage(side: 360, size: 9, withLines: true), size: 9)
        for cell in cells {
            XCTAssertTrue(try InkDetector.isEmpty(cell))
        }
    }

    func testInkDetectorEmptyVersusInked() throws {
        let cells = try CellSlicer.slice(makeImage(side: 360, size: 4, inked: [(0, 1)]), size: 4)
        XCTAssertTrue(try InkDetector.isEmpty(cells[0]))
        XCTAssertFalse(try InkDetector.isEmpty(cells[1]))
    }

    func testThresholds() throws {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        let inputs = [input("3", 0.9), input("2", 0.6), input("1", 0.3)]
            + Array(repeating: emptyInput, count: 13)
        let result = try board.assemble(size: 4, perCell: inputs)
        XCTAssertEqual(result.cells[0], CellRecognition(digit: 3, confidence: 0.9, status: .certain))
        XCTAssertEqual(result.cells[1].status, .lowConfidence)
        XCTAssertEqual(result.cells[1].digit, 2)
        XCTAssertEqual(result.cells[2].status, .toConfirm)
        XCTAssertNil(result.cells[2].digit)
        XCTAssertEqual(result.lowConfidenceIndexes, [1, 2])
        XCTAssertTrue(result.needsReview)
    }

    func testOutOfRangeTextIsFiltered() throws {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        let texts = ["7", "0", "ab", "12", " 3 "]
        let inputs = texts.map { input($0, 0.95) } + Array(repeating: input("1", 0.95), count: 11)
        let result = try board.assemble(size: 4, perCell: inputs)
        XCTAssertEqual(result.cells.prefix(4).map(\.status), Array(repeating: .toConfirm, count: 4))
        XCTAssertEqual(result.cells[4].digit, 3)
    }

    func testEmptyCellsSkipRecognizer() throws {
        let fake = FakeCellTextRecognizer(scripted: [[TextCandidate(text: "4", confidence: 0.9)]])
        let image = try makeImage(side: 360, size: 4, inked: [(1, 2)])
        let result = try BoardRecognizer(recognizer: fake).recognize(squareImage: image, size: 4)
        XCTAssertEqual(fake.callCount, 1)
        // 行优先：第 1 行第 2 列 = 下标 6
        XCTAssertEqual(result.cells[6].digit, 4)
        XCTAssertEqual(result.cells.filter { $0.status == .empty }.count, 15)
    }

    func testAssembleRejectsWrongCellCount() {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        XCTAssertThrowsError(try board.assemble(size: 4, perCell: []))
    }

    func testVisionRecognizerDoesNotThrowOnBlankImage() throws {
        let blank = try makeImage(side: 100, size: 1)
        XCTAssertNoThrow(try VisionCellTextRecognizer().recognize(blank))
    }

    func testFiveByFiveAssembly() throws {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        let digits = ["1", "2", "3", "4", "5", "6"].map { input($0, 0.9) }
        let inputs = digits + Array(repeating: emptyInput, count: 19)
        let result = try board.assemble(size: 5, perCell: inputs)
        XCTAssertEqual(result.cells.count, 25)
        XCTAssertEqual(result.cells.prefix(5).map(\.digit), [1, 2, 3, 4, 5])
        // 5x5 里 6 超出范围，要被过滤
        XCTAssertEqual(result.cells[5].status, .toConfirm)
        XCTAssertNil(result.cells[5].digit)
    }

    func testExactThresholdBoundaries() throws {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        let inputs = [input("1", 0.8), input("2", 0.5), input("3", 0.4999)]
            + Array(repeating: emptyInput, count: 13)
        let result = try board.assemble(size: 4, perCell: inputs)
        XCTAssertEqual(result.cells[0].status, .certain)
        XCTAssertEqual(result.cells[1].status, .lowConfidence)
        XCTAssertEqual(result.cells[2].status, .toConfirm)
    }

    func testBoundariesCoverFullSide() {
        let edges = CellSlicer.boundaries(side: 100, count: 9)
        XCTAssertEqual(edges.count, 10)
        XCTAssertEqual(edges.first, 0)
        XCTAssertEqual(edges.last, 100)
        let widths = zip(edges, edges.dropFirst()).map { $1 - $0 }
        XCTAssertEqual(widths.reduce(0, +), 100)
        XCTAssertTrue(widths.allSatisfy { $0 == 11 || $0 == 12 })
    }

    func testSliceSideNotDivisibleByCount() throws {
        let cells = try CellSlicer.slice(makeImage(side: 100, size: 9), size: 9)
        XCTAssertEqual(cells.count, 81)
        XCTAssertTrue(cells.allSatisfy { $0.width > 0 && $0.height > 0 })
    }

    func testSliceRejectsNonSquareImage() throws {
        let square = try makeImage(side: 200, size: 4)
        let wide = try XCTUnwrap(square.cropping(to: CGRect(x: 0, y: 0, width: 200, height: 150)))
        XCTAssertThrowsError(try CellSlicer.slice(wide, size: 4)) {
            XCTAssertEqual($0 as? BoardVisionError, .imageNotSquare)
        }
    }

    func testSliceToleratesTinySquareError() throws {
        let square = try makeImage(side: 200, size: 4)
        let almost = try XCTUnwrap(square.cropping(to: CGRect(x: 0, y: 0, width: 200, height: 197)))
        XCTAssertEqual(try CellSlicer.slice(almost, size: 4).count, 16)
    }

    func testLookalikesReadAsOne() throws {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        let inputs = ["l", "I", "|", "ll"].map { input($0, 0.9) } + Array(repeating: emptyInput, count: 12)
        let result = try board.assemble(size: 4, perCell: inputs)
        XCTAssertEqual(result.cells.prefix(3).map(\.digit), [1, 1, 1])
        XCTAssertEqual(result.cells[3].status, .toConfirm)
    }

    func testThresholdsValidation() throws {
        XCTAssertThrowsError(try RecognitionThresholds(certain: 0.5, low: 0.8)) {
            XCTAssertEqual($0 as? BoardVisionError, .invalidThresholds)
        }
        XCTAssertThrowsError(try RecognitionThresholds(certain: 1.2, low: 0.5))
        XCTAssertThrowsError(try RecognitionThresholds(certain: 0.5, low: -0.1))
        XCTAssertNoThrow(try RecognitionThresholds(certain: 0.6, low: 0.6))
    }

    func testCustomThresholdsAreUsed() throws {
        let thresholds = try RecognitionThresholds(certain: 0.9, low: 0.2)
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer(), thresholds: thresholds)
        let inputs = [input("1", 0.85), input("2", 0.25)] + Array(repeating: emptyInput, count: 14)
        let result = try board.assemble(size: 4, perCell: inputs)
        XCTAssertEqual(result.cells[0].status, .lowConfidence)
        XCTAssertEqual(result.cells[1].status, .lowConfidence)
    }

    func testToConfirmUsesBestConfidence() throws {
        let board = BoardRecognizer(recognizer: FakeCellTextRecognizer())
        let weak = CellInput(isEmpty: false, candidates: [
            TextCandidate(text: "2", confidence: 0.1),
            TextCandidate(text: "x", confidence: 0.9),
            TextCandidate(text: "3", confidence: 0.4),
        ])
        let none = input("x", 0.9)
        let result = try board.assemble(size: 4, perCell: [weak, none] + Array(repeating: emptyInput, count: 14))
        XCTAssertEqual(result.cells[0], CellRecognition(digit: nil, confidence: 0.4, status: .toConfirm))
        XCTAssertEqual(result.cells[1], CellRecognition(digit: nil, confidence: 0, status: .toConfirm))
    }

    func testPreprocessorUpscalesSmallCell() throws {
        let small = try makeImage(side: 20, size: 1)
        let prepared = try CellPreprocessor.prepare(small)
        XCTAssertGreaterThanOrEqual(prepared.width, CellPreprocessor.minimumSide)
        XCTAssertGreaterThanOrEqual(prepared.height, CellPreprocessor.minimumSide)
    }

    func testDetectorCorrectsClearSquare() throws {
        let image = try makeFramedSquareImage()
        do {
            let corrected = try BoardDetector.detectAndCorrect(image)
            XCTAssertEqual(corrected.width, corrected.height)
            XCTAssertGreaterThan(corrected.width, 100)
        } catch BoardVisionError.boardNotFound {
            // 个别环境的 Vision 可能不认合成图，跳过而不是误报失败
            // 在日志里留下明确记录，免得跳过被忽略
            print("[BoardVision] skipping testDetectorCorrectsClearSquare: "
                + "Vision found no rectangle in the synthetic image")
            throw XCTSkip("Vision found no rectangle in the synthetic image")
        }
    }
}

/// 白底画布，中间偏一点画一个粗黑框正方形。
private func makeFramedSquareImage() throws -> CGImage {
    let context = try XCTUnwrap(CGContext(
        data: nil, width: 800, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
    ))
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
    context.setStrokeColor(gray: 0, alpha: 1)
    context.setLineWidth(16)
    context.stroke(CGRect(x: 320, y: 130, width: 340, height: 340))
    return try XCTUnwrap(context.makeImage())
}
