import CoreGraphics

/// 用深色像素占比判断小图是否为空格。
public enum InkDetector {
    /// 亮度低于它的像素算墨迹（0...255）。
    public static let luminanceThreshold: UInt8 = 128
    /// 墨迹占比低于它判为空格。
    public static let emptyRatio = 0.02

    /// 深色像素占比，0...1。
    public static func inkRatio(of image: CGImage) throws -> Double {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { throw BoardVisionError.imageProcessingFailed }
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            // 灰度上下文会把彩色图自动转成亮度
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw BoardVisionError.imageProcessingFailed }
        let inkCount = pixels.filter { $0 < luminanceThreshold }.count
        return Double(inkCount) / Double(pixels.count)
    }

    public static func isEmpty(_ image: CGImage) throws -> Bool {
        try inkRatio(of: image) < emptyRatio
    }
}
