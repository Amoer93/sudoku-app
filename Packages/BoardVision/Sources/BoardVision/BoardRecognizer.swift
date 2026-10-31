import CoreGraphics
import Foundation

/// 单格的组装输入：是否空格，加识别器给出的候选。
public struct CellInput: Sendable {
    public let isEmpty: Bool
    public let candidates: [TextCandidate]

    public init(isEmpty: Bool, candidates: [TextCandidate]) {
        self.isEmpty = isEmpty
        self.candidates = candidates
    }
}

/// 置信度分级阈值，先定一版，之后用样本调。
public struct RecognitionThresholds: Sendable {
    public let certain: Double
    public let low: Double

    /// 默认阈值。
    public init() {
        certain = 0.8
        low = 0.5
    }

    /// 自定义阈值；两者都要在 0...1，且 low 不能高于 certain，否则分级会自相矛盾。
    public init(certain: Double, low: Double) throws {
        let validRange = 0.0 ... 1.0
        guard validRange.contains(certain), validRange.contains(low), low <= certain else {
            throw BoardVisionError.invalidThresholds
        }
        self.certain = certain
        self.low = low
    }
}

/// 切格、判空、识别、组装成 RecognitionResult。
public struct BoardRecognizer {
    private let recognizer: CellTextRecognizer
    private let thresholds: RecognitionThresholds

    public init(recognizer: CellTextRecognizer, thresholds: RecognitionThresholds = RecognitionThresholds()) {
        self.recognizer = recognizer
        self.thresholds = thresholds
    }

    public func recognize(squareImage: CGImage, size: Int) throws -> RecognitionResult {
        let cells = try CellSlicer.slice(squareImage, size: size)
        var inputs: [CellInput] = []
        for cell in cells {
            // 空格不调 Vision，省时间
            if try InkDetector.isEmpty(cell) {
                inputs.append(CellInput(isEmpty: true, candidates: []))
            } else {
                inputs.append(CellInput(isEmpty: false, candidates: try recognizer.recognize(cell)))
            }
        }
        return try assemble(size: size, perCell: inputs)
    }

    /// 纯逻辑：把每格输入变成结果，不碰图片。
    public func assemble(size: Int, perCell: [CellInput]) throws -> RecognitionResult {
        guard perCell.count == size * size else { throw BoardVisionError.cellCountMismatch }
        return RecognitionResult(size: size, cells: perCell.map { classify($0, size: size) })
    }

    private func classify(_ input: CellInput, size: Int) -> CellRecognition {
        if input.isEmpty { return CellRecognition(digit: nil, confidence: 1, status: .empty) }
        let valid = input.candidates.compactMap { candidate -> (digit: Int, confidence: Double)? in
            guard let digit = Self.digit(from: candidate.text, size: size) else { return nil }
            return (digit, candidate.confidence)
        }
        // 有墨迹但读不出合法数字，交给用户确认，不默认当空
        let best = valid.max(by: { $0.confidence < $1.confidence })
        guard let best, best.confidence >= thresholds.low else {
            // 待确认格展示最高的那个置信度，没有合法候选就是 0
            return CellRecognition(digit: nil, confidence: best?.confidence ?? 0, status: .toConfirm)
        }
        let status: CellStatus = best.confidence >= thresholds.certain ? .certain : .lowConfidence
        return CellRecognition(digit: best.digit, confidence: best.confidence, status: status)
    }

    /// 常被 OCR 当成数字 1 的字符。
    private static let oneLookalikes: Set<String> = ["l", "I", "|"]

    /// 只认单个字符、值在 1...size 的数字；l、I、| 先当成 1。
    private static func digit(from text: String, size: Int) -> Int? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 只有单字符才替换，避免把 "Il" 这类文字误当数字
        if oneLookalikes.contains(trimmed) { trimmed = "1" }
        guard trimmed.count == 1, let value = Int(trimmed), (1 ... size).contains(value) else { return nil }
        return value
    }
}
