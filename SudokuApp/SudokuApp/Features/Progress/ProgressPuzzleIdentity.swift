import SudokuEngine

/// 记进度时用的题目身份。没有稳定身份的题（拍照导入、9×9 固定题）不记。
struct ProgressPuzzleIdentity: Equatable {
    let id: PuzzleFingerprint
    /// 固定题没有难度，不能随便标成「简单」。
    let difficulty: Difficulty?
    let size: Int

    /// - Parameter isCustomPuzzle: 外部传进来的题面（拍照导入等），不是内置固定题。
    init?(bankEntry: PuzzleBankEntry?, preset: BoardPreset, isCustomPuzzle: Bool) {
        if let bankEntry {
            id = bankEntry.id
            difficulty = bankEntry.difficulty
            size = bankEntry.size
            return
        }
        // 拍照导入的 4×4 也会带着 preset 进来，不能当成固定题
        guard !isCustomPuzzle else {
            return nil
        }
        switch preset {
        case .four:
            id = PuzzleFingerprint(value: "fixture-4")
            size = 4
        case .five:
            id = PuzzleFingerprint(value: "fixture-5")
            size = 5
        case .nine:
            return nil
        }
        difficulty = nil
    }
}
