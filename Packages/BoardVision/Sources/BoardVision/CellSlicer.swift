import CoreGraphics

/// 把已校正的方图切成 n×n 小图。
public enum CellSlicer {
    public static let supportedSizes: Set<Int> = [4, 5, 9]
    /// 每边裁掉的比例，用来去掉格线。
    public static let insetRatio = 0.08

    /// 返回行优先的小图。
    public static func slice(_ image: CGImage, size: Int) throws -> [CGImage] {
        guard supportedSizes.contains(size) else { throw BoardVisionError.unsupportedSize(size) }
        guard image.width == image.height else { throw BoardVisionError.imageNotSquare }
        let cellSide = image.width / size
        let inset = Int(Double(cellSide) * insetRatio)
        var cells: [CGImage] = []
        for row in 0 ..< size {
            for column in 0 ..< size {
                let rect = CGRect(
                    x: column * cellSide + inset,
                    y: row * cellSide + inset,
                    width: cellSide - 2 * inset,
                    height: cellSide - 2 * inset
                )
                // 裁剪失败只可能是图太小，直接报错，不猜
                guard let cell = image.cropping(to: rect) else { throw BoardVisionError.imageProcessingFailed }
                cells.append(cell)
            }
        }
        return cells
    }
}
