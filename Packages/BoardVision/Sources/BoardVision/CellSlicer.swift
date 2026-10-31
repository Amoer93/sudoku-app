import CoreGraphics

/// 把已校正的方图切成 n×n 小图。
public enum CellSlicer {
    public static let supportedSizes: Set<Int> = [4, 5, 9]
    /// 每边裁掉的比例，用来去掉格线。
    public static let insetRatio = 0.08
    /// 宽高允许的差距比例，超过就认为不是方图。
    public static let squareTolerance = 0.02

    /// 返回行优先的小图。
    public static func slice(_ image: CGImage, size: Int) throws -> [CGImage] {
        guard supportedSizes.contains(size) else { throw BoardVisionError.unsupportedSize(size) }
        guard isSquare(width: image.width, height: image.height) else { throw BoardVisionError.imageNotSquare }
        // 略有误差时取短边，保证不会裁出图外
        let edges = boundaries(side: min(image.width, image.height), count: size)
        var cells: [CGImage] = []
        for row in 0 ..< size {
            for column in 0 ..< size {
                let rect = trimmedRect(left: edges[column], right: edges[column + 1],
                                       top: edges[row], bottom: edges[row + 1])
                // 裁剪失败只可能是图太小，直接报错，不猜
                guard let cell = image.cropping(to: rect) else { throw BoardVisionError.imageProcessingFailed }
                cells.append(cell)
            }
        }
        return cells
    }

    /// 把边长按四舍五入均分成 count 段，返回 count + 1 个分界；首个是 0，末个是 side，不丢像素。
    static func boundaries(side: Int, count: Int) -> [Int] {
        (0 ... count).map { index in
            Int((Double(index) * Double(side) / Double(count)).rounded())
        }
    }

    private static func isSquare(width: Int, height: Int) -> Bool {
        let difference = abs(width - height)
        return Double(difference) <= Double(max(width, height)) * squareTolerance
    }

    /// 在格子范围内每边裁掉一点，去掉格线。
    private static func trimmedRect(left: Int, right: Int, top: Int, bottom: Int) -> CGRect {
        let width = right - left
        let height = bottom - top
        let inset = Int(Double(min(width, height)) * insetRatio)
        return CGRect(x: left + inset, y: top + inset, width: width - 2 * inset, height: height - 2 * inset)
    }
}
