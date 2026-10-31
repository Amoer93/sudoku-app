import CoreGraphics
import Vision

public struct TextCandidate: Equatable, Sendable {
    public let text: String
    public let confidence: Double

    public init(text: String, confidence: Double) {
        self.text = text
        self.confidence = confidence
    }
}

/// 读一格里的文字。放在协议后面，测试里用假实现。
public protocol CellTextRecognizer {
    func recognize(_ cell: CGImage) throws -> [TextCandidate]
}

/// 用 Vision 同步识别单格文字。
public struct VisionCellTextRecognizer: CellTextRecognizer {
    public static let candidateLimit = 3

    public init() {}

    public func recognize(_ cell: CGImage) throws -> [TextCandidate] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // 数字不是单词，语言纠错会把它改坏
        request.usesLanguageCorrection = false
        // 只认英文数字，别的语言模型会把数字读成别的字
        request.recognitionLanguages = ["en-US"]
        let prepared = try CellPreprocessor.prepare(cell)
        try VNImageRequestHandler(cgImage: prepared, options: [:]).perform([request])
        let observations = request.results ?? []
        return observations.flatMap { observation in
            observation.topCandidates(Self.candidateLimit).map {
                TextCandidate(text: $0.string, confidence: Double($0.confidence))
            }
        }
    }
}
