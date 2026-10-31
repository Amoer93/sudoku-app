import BoardVision

/// 把 BoardVision 的识别结果转成 App 自己的 Grid。
enum RecognitionGridAdapter {
    /// 转成 Grid；空格（digit 为 nil）写成 `Grid.emptyCell`。
    /// 边长、格数或数字不合法时由 Grid 的构造器抛错。
    static func makeGrid(_ result: RecognitionResult) throws -> Grid {
        let digits = result.cells.map { $0.digit ?? Grid.emptyCell }
        return try Grid(size: result.size, cells: digits)
    }

    /// 需要用户复核的格子下标：低置信度或待确认。
    static func reviewIndexes(_ result: RecognitionResult) -> Set<Int> {
        var indexes = Set<Int>()
        for (index, cell) in result.cells.enumerated() {
            if cell.status == .lowConfidence || cell.status == .toConfirm {
                indexes.insert(index)
            }
        }
        return indexes
    }
}
