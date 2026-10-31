import SudokuEngine
@testable import SudokuEngine
import XCTest

let difficultySolutionString =
    "483921657967345821251876493548132976729564138136798245372689514814253769695417382"
let difficultyEasyPuzzle =
    "003020600900305001001806400008102900700000008006708200002609500800203009005010300"
let difficultyHardPuzzle =
    "800000000003600000070090200050007000000045700000100030001000068008500010090000400"

func emptyBoard() -> GradingBoard? {
    GradingBoard(grid: Grid(rules: .nineByNine), solution: makeGrid(difficultySolutionString))
}

func mask(_ digits: [Int]) -> UInt16 {
    digits.reduce(UInt16(0)) { $0 | (1 << UInt16($1 - 1)) }
}

func makeGrid(_ text: String) -> Grid {
    let cells = text.compactMap { character -> Int? in
        if character == "." || character == "0" { return 0 }
        return character.wholeNumberValue
    }
    return (try? Grid(size: 9, cells: cells)) ?? Grid(rules: .nineByNine)
}

func hasCandidate(_ board: GradingBoard, digit: Int, at cell: Int) -> Bool {
    board.candidates[cell] & (1 << UInt16(digit - 1)) != 0
}

func remove(digit: Int, from cells: [Int], board: inout GradingBoard) {
    for cell in cells { board.clearCandidate(digit: digit, at: cell) }
}

func remove(digits: [Int], from cells: [Int], board: inout GradingBoard) {
    for digit in digits { remove(digit: digit, from: cells, board: &board) }
}

func rowCells(_ row: Int) -> [Int] {
    (0 ..< 9).map { row * 9 + $0 }
}

func colCells(_ col: Int) -> [Int] {
    (0 ..< 9).map { $0 * 9 + col }
}

func boxCells(_ box: Int) -> [Int] {
    let boxRow = box / 3
    let boxCol = box % 3
    var cells: [Int] = []
    for row in boxRow * 3 ..< boxRow * 3 + 3 {
        for col in boxCol * 3 ..< boxCol * 3 + 3 {
            cells.append(row * 9 + col)
        }
    }
    return cells
}
