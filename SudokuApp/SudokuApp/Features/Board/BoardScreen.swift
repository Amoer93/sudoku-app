import SudokuEngine
import SwiftUI

/// 一局棋盘：选格、输入、冲突高亮、撤销和自动解题。
/// 视图会被父视图反复重建，所以 ViewModel 只在第一次出现时创建一次，
/// 避免每次 init 都新建模型、在主线程多算一次 `conflicts`。
struct BoardScreen: View {
    let preset: BoardPreset
    /// 指定题目（如拍照导入）；为空就用内置题
    let puzzle: SamplePuzzle?
    let notice: ImportNotice?
    /// 题来自题库时的条目；用来在顶部显示「需试错」，为空就不显示
    let bankEntry: PuzzleBankEntry?
    let engine: any SudokuBoardEngine
    @State private var model: BoardViewModel?
    @State private var banner = ImportBannerState()
    @State private var existingPuzzle: SamplePuzzle?
    @State private var isExistingShown = false

    init(
        preset: BoardPreset,
        puzzle: SamplePuzzle? = nil,
        notice: ImportNotice? = nil,
        bankEntry: PuzzleBankEntry? = nil,
        engine: any SudokuBoardEngine = EngineBoardAdapter()
    ) {
        self.preset = preset
        self.puzzle = puzzle
        self.notice = notice
        self.bankEntry = bankEntry
        self.engine = engine
    }

    var body: some View {
        content
            .overlay(alignment: .top) {
                if let current = banner.notice {
                    ImportNoticeBanner(notice: current, onOpenExisting: openExisting, onDismiss: banner.dismiss)
                }
            }
            .animation(.default, value: banner.notice)
            .onChange(of: notice) { _, newNotice in
                // 入库在后台做，提示可能在棋盘出现之后才到
                if let newNotice {
                    banner.show(newNotice)
                }
            }
            .navigationDestination(isPresented: $isExistingShown) {
                if let existingPuzzle {
                    BoardScreen(preset: .nine, puzzle: existingPuzzle)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            BoardContentView(model: model, bankEntry: bankEntry)
        } else {
            ProgressView()
                .onAppear {
                    // 只建一次；之后父视图重建不会再进这里
                    let start = puzzle ?? FixtureLibrary.puzzle(for: preset)
                    model = BoardViewModel(title: preset.title, puzzle: start, engine: engine)
                    if let notice {
                        banner.show(notice)
                    }
                }
        }
    }

    private func openExisting() {
        Task {
            existingPuzzle = await banner.existingPuzzle()
            banner.dismiss()
            isExistingShown = existingPuzzle != nil
        }
    }
}

/// 棋盘主体，持有已经创建好的 ViewModel。
private struct BoardContentView: View {
    @Bindable var model: BoardViewModel
    let bankEntry: PuzzleBankEntry?
    // 后台评级完成后才变 true
    @State private var needsTrial = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if needsTrial {
                    TrialTagView()
                }
                status
                board
                controls
                layerControls
                solveButton
                Toggle(BoardCopy.autoFilter, isOn: $model.isAutoFilterOn)
                    .accessibilityHint(BoardCopy.autoFilterHint)
                NumberPadView(
                    size: model.rules.size,
                    isEnabled: model.canEnter,
                    disabledDigits: model.disabledValues,
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
        .task {
            if let bankEntry {
                needsTrial = await TrialTagCache.shared.needsTrial(for: bankEntry)
            }
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
            BoardActionButton(
                title: BoardCopy.hint,
                systemImage: "lightbulb",
                hint: BoardCopy.hintHint,
                isEnabled: !model.isSolving,
                action: {
                    model.showHint()
                }
            )
        }
    }

    private var layerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BoardCopy.layerStatus(model.currentLayerDepth))
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                BoardActionButton(
                    title: BoardCopy.startLayer,
                    systemImage: "square.3.layers.3d",
                    hint: BoardCopy.startLayerHint,
                    isEnabled: model.canStartLayer,
                    action: {
                        model.startLayer()
                    }
                )
                BoardActionButton(
                    title: BoardCopy.rollbackLayer,
                    systemImage: "arrow.uturn.backward.circle",
                    hint: BoardCopy.rollbackLayerHint,
                    isEnabled: model.canRollbackLayer,
                    action: {
                        model.rollbackLayer()
                    }
                )
            }
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
        // 预览用替身引擎，不跑真求解
        BoardScreen(preset: .four, engine: FixtureBoardEngine())
    }
}
