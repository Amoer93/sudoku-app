import Foundation

/// 单格识别状态。
public enum CellStatus: Equatable, Sendable {
    case certain
    case lowConfidence
    case toConfirm
    case empty
}

/// 单格识别结果；digit 为 nil 表示空格或没读出来。
public struct CellRecognition: Equatable, Sendable {
    public let digit: Int?
    public let confidence: Double
    public let status: CellStatus

    public init(digit: Int?, confidence: Double, status: CellStatus) {
        self.digit = digit
        self.confidence = confidence
        self.status = status
    }
}

/// 整盘识别结果，cells 按行优先排列。
public struct RecognitionResult: Equatable, Sendable {
    public let size: Int
    public let cells: [CellRecognition]

    public init(size: Int, cells: [CellRecognition]) {
        self.size = size
        self.cells = cells
    }

    /// 需要用户看一眼的格子下标（低置信度或待确认）。
    public var lowConfidenceIndexes: [Int] {
        cells.indices.filter { cells[$0].status == .lowConfidence || cells[$0].status == .toConfirm }
    }

    public var needsReview: Bool {
        !lowConfidenceIndexes.isEmpty
    }
}

public enum BoardVisionError: Error, Equatable {
    case unsupportedSize(Int)
    case imageNotSquare
    case imageProcessingFailed
    case cellCountMismatch
    case boardNotFound
    case invalidThresholds
}
