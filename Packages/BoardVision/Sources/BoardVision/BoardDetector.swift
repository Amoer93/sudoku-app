import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// 在照片里找出棋盘，并校正成方图。
public enum BoardDetector {
    /// 找到最大的近似方形并做透视校正；找不到抛 boardNotFound。
    public static func detectAndCorrect(_ image: CGImage) throws -> CGImage {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.8
        request.maximumObservations = 1
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let found = request.results ?? []
        let largest = found.max { area(of: $0) < area(of: $1) }
        guard let largest else { throw BoardVisionError.boardNotFound }
        return try correct(image, to: largest)
    }

    private static func area(of observation: VNRectangleObservation) -> Double {
        Double(observation.boundingBox.width * observation.boundingBox.height)
    }

    /// 把四个角拉成正方形。
    private static func correct(_ image: CGImage, to observation: VNRectangleObservation) throws -> CGImage {
        let width = Double(image.width)
        let height = Double(image.height)
        // Vision 的坐标是 0...1、原点在左下；CIImage 的原点也在左下，只需乘上像素尺寸
        func pixelPoint(_ point: CGPoint) -> CGPoint {
            CGPoint(x: Double(point.x) * width, y: Double(point.y) * height)
        }
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = CIImage(cgImage: image)
        filter.topLeft = pixelPoint(observation.topLeft)
        filter.topRight = pixelPoint(observation.topRight)
        filter.bottomLeft = pixelPoint(observation.bottomLeft)
        filter.bottomRight = pixelPoint(observation.bottomRight)
        guard let corrected = filter.outputImage else { throw BoardVisionError.imageProcessingFailed }
        return try renderSquare(corrected)
    }

    /// 输出边长取校正图宽高的平均值，宽高不等时拉伸成正方形。
    private static func renderSquare(_ corrected: CIImage) throws -> CGImage {
        let extent = corrected.extent
        let side = ((extent.width + extent.height) / 2).rounded()
        guard side > 0 else { throw BoardVisionError.imageProcessingFailed }
        let transform = CGAffineTransform(scaleX: side / extent.width, y: side / extent.height)
            .translatedBy(x: -extent.minX, y: -extent.minY)
        let squared = corrected.transformed(by: transform)
        let outputRect = CGRect(x: 0, y: 0, width: side, height: side)
        guard let output = CIContext().createCGImage(squared, from: outputRect) else {
            throw BoardVisionError.imageProcessingFailed
        }
        return output
    }
}
