import SudokuEngine
import XCTest

final class SolverInterfaceTests: XCTestCase {
    /// 钉住三个入口的类型。函数体仍是占位，这里不调用它们。
    func testFrozenFunctionTypes() {
        expectType(((Grid, Rules) -> Set<CellIndex>).self, conflicts(in:rules:))
        expectType(((Grid, Rules) -> Grid?).self, solve(_:rules:))
        expectType(((Grid, Rules, Int) -> Int).self, solutionCount(_:rules:limit:))
    }

    func testModelsAreSendableValues() {
        acceptsSendable(Rules.nineByNine)
        acceptsSendable(Grid(rules: .fiveByFive))
        acceptsSendable(CellIndex(row: 0, column: 0))
        acceptsSendable(Grid.emptyCell)
    }
}

private func expectType<T>(_: T.Type, _: T) {}

private func acceptsSendable<T: Sendable>(_: T) {}
