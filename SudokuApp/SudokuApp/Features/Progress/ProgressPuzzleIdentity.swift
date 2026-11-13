import SudokuEngine

/// 记进度时用的题目身份。没有稳定身份的题（拍照导入、9×9 固定题）不记。
struct ProgressPuzzleIdentity: Equatable {
    let id: PuzzleFingerprint
    let difficulty: Difficulty? // 固定题为 nil
    let size: Int

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
