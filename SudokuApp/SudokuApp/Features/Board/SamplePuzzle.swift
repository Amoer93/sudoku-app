/// 一道写死的示例题。答案只给替身引擎用，视图拿不到。
struct SamplePuzzle: Equatable, Sendable {
    let rules: Rules
    let givens: Grid
    let solution: Grid
}

/// 把题面字符串转成格子。点号是空格，其余按数字读。
enum DigitRows {
    static func grid(_ rows: [String]) -> Grid {
        Grid(cells: rows.flatMap(cells(in:)))
    }

    private static func cells(in row: String) -> [Int] {
        var values: [Int] = []
        for character in row {
            if let digit = character.wholeNumberValue {
                values.append(digit)
            } else if character == "." {
                values.append(0)
            }
        }
        return values
    }
}

/// 每种尺寸一题。数字是固定题面，不是算出来的。
enum FixtureLibrary {
    static func puzzle(for preset: BoardPreset) -> SamplePuzzle {
        switch preset {
        case .four:
            return four
        case .five:
            return five
        case .nine:
            return nine
        }
    }

    static var all: [SamplePuzzle] {
        BoardPreset.allCases.map { puzzle(for: $0) }
    }

    private static let four = SamplePuzzle(
        rules: BoardPreset.four.rules,
        givens: DigitRows.grid(["123.", "3.12", ".143", "432."]),
        solution: DigitRows.grid(["1234", "3412", "2143", "4321"])
    )

    private static let five = SamplePuzzle(
        rules: BoardPreset.five.rules,
        givens: DigitRows.grid(["12.45", "2.451", ".4512", "451.3", "512.4"]),
        solution: DigitRows.grid(["12345", "23451", "34512", "45123", "51234"])
    )

    private static let nine = SamplePuzzle(
        rules: BoardPreset.nine.rules,
        givens: DigitRows.grid([
            "53..7....",
            "6..195...",
            ".98....6.",
            "8...6...3",
            "4..8.3..1",
            "7...2...6",
            ".6....28.",
            "...419..5",
            "....8..79",
        ]),
        solution: DigitRows.grid([
            "534678912",
            "672195348",
            "198342567",
            "859761423",
            "426853791",
            "713924856",
            "961537284",
            "287419635",
            "345286179",
        ])
    )
}
