import CoreGraphics

/// 识别前处理单格小图：放大太小的图，四周补白边。
enum CellPreprocessor {
    /// 短边小于它就放大到它（像素）。
    static let minimumSide = 64
    /// 四周补的白边宽度（像素）；贴边的字 Vision 容易读错。
    static let margin = 16

    /// 返回放大并补白边后的灰度图。
    static func prepare(_ cell: CGImage) throws -> CGImage {
        let shortSide = min(cell.width, cell.height)
        guard shortSide > 0 else { throw BoardVisionError.imageProcessingFailed }
        // 只放大不缩小，大图保持原样
        let scale = shortSide < minimumSide ? Double(minimumSide) / Double(shortSide) : 1
        let drawWidth = Int((Double(cell.width) * scale).rounded())
        let drawHeight = Int((Double(cell.height) * scale).rounded())
        let canvasWidth = drawWidth + 2 * margin
        let canvasHeight = drawHeight + 2 * margin
        guard let context = CGContext(
            data: nil, width: canvasWidth, height: canvasHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw BoardVisionError.imageProcessingFailed }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        context.interpolationQuality = .high
        context.draw(cell, in: CGRect(x: margin, y: margin, width: drawWidth, height: drawHeight))
        guard let output = context.makeImage() else { throw BoardVisionError.imageProcessingFailed }
        return output
    }
}
