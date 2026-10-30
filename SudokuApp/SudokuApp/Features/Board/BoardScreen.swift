import SwiftUI

/// 一局棋盘：选格、输入、冲突高亮、撤销和自动解题。
/// 视图会被父视图反复重建，所以 ViewModel 只在第一次出现时创建一次，
/// 避免每次 init 都新建模型、在主线程多算一次 `conflicts`。
struct BoardScreen: View {
    let preset: BoardPreset
    let engine: any SudokuBoardEngine
    @State private var model: BoardViewModel?

    init(preset: BoardPreset, engine: any SudokuBoardEngine = FixtureBoardEngine()) {
        self.preset = preset
        self.engine = engine
    }

    var body: some View {
        if let model {
            BoardContentView(model: model)
        } else {
            ProgressView()
                .onAppear {
                    // 只建一次；之后父视图重建不会再进这里
                    let puzzle = FixtureLibrary.puzzle(for: preset)
                    model = BoardViewModel(title: preset.title, puzzle: puzzle, engine: engine)
                }
        }
    }
}

/// 棋盘主体，持有已经创建好的 ViewModel。
private struct BoardContentView: View {
    let model: BoardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                status
                board
                controls
                solveButton
                NumberPadView(
                    size: model.rules.size,
                    isEnabled: model.canEnter,
                    onDigit: { digit in
                        model.enter(digit)
                    },
                    onClear: {
                        model.clearSelected()
                    }
                )
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.refreshSolutionCount()
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.statusText)
                .font(.subheadline)
                .foregroundStyle(model.statusIsWarning ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.solutionCountText)
                .font(.footnote)
                .foregroundStyle(model.solutionCountIsWarning ? Color.red : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var board: some View {
        BoardGridView(rules: model.rules, cells: model.cellStates) { index in
            model.select(index: index)
        }
        .opacity(model.isSolving ? 0.55 : 1)
        .allowsHitTesting(!model.isSolving)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            BoardActionButton(
                title: BoardCopy.undo,
                systemImage: "arrow.uturn.backward",
                hint: BoardCopy.undoHint,
                isEnabled: model.canUndo,
                action: {
                    model.undo()
                }
            )
            BoardActionButton(
                title: BoardCopy.redo,
                systemImage: "arrow.uturn.forward",
                hint: BoardCopy.redoHint,
                isEnabled: model.canRedo,
                action: {
                    model.redo()
                }
            )
            BoardActionButton(
                title: BoardCopy.clearAll,
                systemImage: "eraser",
                hint: BoardCopy.clearAllHint,
                isEnabled: model.canClear,
                action: {
                    model.clearUserEntries()
                }
            )
        }
    }

    private var solveButton: some View {
        Button {
            Task {
                await model.autoSolve()
            }
        } label: {
            solveLabel
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isSolving)
        .accessibilityLabel(model.isSolving ? BoardCopy.solving : BoardCopy.autoSolve)
    }

    private var solveLabel: some View {
        HStack(spacing: 8) {
            if model.isSolving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "wand.and.stars")
                    .accessibilityHidden(true)
            }
            Text(BoardCopy.autoSolve)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// 撤销、重做、清空。图标配短标题，小屏上也能点到。
private struct BoardActionButton: View {
    let title: String
    let systemImage: String
    let hint: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }
}

#Preview {
    NavigationStack {
        BoardScreen(preset: .four)
    }
}
