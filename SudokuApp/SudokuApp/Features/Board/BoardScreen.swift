import SudokuEngine
import SwiftUI

/// 一局棋盘：选格、输入、冲突高亮、撤销和全解。
/// 视图会被父视图反复重建，所以 ViewModel 只在第一次出现时创建一次，
/// 避免每次 init 都新建模型、在主线程多算一次 `conflicts`。
struct BoardScreen: View {
    let preset: BoardPreset
    /// 指定题目（如拍照导入）；为空就用内置题
    let puzzle: SamplePuzzle?
    let notice: ImportNotice?
    /// 题来自题库时的条目；用来在顶部显示「先猜一猜」，为空就不显示
    let bankEntry: PuzzleBankEntry?
    let engine: any SudokuBoardEngine
    // 预览和测试没有注入进度时为空，不存也不恢复
    @Environment(PuzzleProgressModel.self) private var progress: PuzzleProgressModel?
    @State private var model: BoardViewModel?
    @State private var autosave: BoardSessionAutosave?
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
            BoardContentView(model: model, bankEntry: bankEntry, identity: progressIdentity, autosave: autosave)
        } else {
            ProgressView()
                .onAppear {
                    // 只建一次；之后父视图重建不会再进这里
                    let start = puzzle ?? FixtureLibrary.puzzle(for: preset)
                    let launch = BoardSessionLauncher.start(
                        title: preset.title, puzzle: start, identity: progressIdentity,
                        progress: progress, engine: engine
                    )
                    model = launch.model
                    autosave = launch.autosave
                    if let shown = notice ?? launch.lostNotice {
                        banner.show(shown)
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
    /// 要记进度的题；拍照导入等不记的题为空
    let identity: ProgressPuzzleIdentity?
    /// 自动存档；没有身份或没有进度模型时为空
    let autosave: BoardSessionAutosave?
    // 预览和测试没有注入进度时为空，什么都不记
    @Environment(PuzzleProgressModel.self) private var progress: PuzzleProgressModel?
    // 后台评级完成后才变 true
    @State private var needsTrial = false
    @AppStorage("showCandidates") private var showCandidates = false
    @AppStorage(BoardHighlightStyle.storageKey) private var highlightPeers = BoardHighlightStyle.defaultEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if needsTrial {
                    TrialTagView()
                }
                status
                layerControls
                candidatesToggle
                board
                controls
                filterToggles
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
        .background(AppTheme.pageBackground.ignoresSafeArea())
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
        .onAppear {
            if let identity {
                progress?.setLastPlayed(id: identity.id, difficulty: identity.difficulty, size: identity.size)
                model.onPlayerCompleted = {
                    progress?.markCompleted(id: identity.id)
                    autosave?.clear()
                }
            }
        }
        .autosaving(autosave, model: model)
    }

    private func clearEntries() {
        model.clearUserEntries()
        // 提示文案是 .cleared 才说明真的清掉了；这时存档也一起删
        if model.notice == .cleared {
            autosave?.clear()
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
        BoardGridView(
            rules: model.rules,
            cells: model.cellStates(showingCandidates: showCandidates, highlightingPeers: highlightPeers)
        ) { index in
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
                    clearEntries()
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
            // 「全解」紧跟在「提示」后面
            solveButton
        }
    }

    /// 蒙版控制放在棋盘上方，一行排完。
    private var layerControls: some View {
        HStack(spacing: 8) {
            // 0 层没有状态可说，不显示这行字
            if model.currentLayerDepth > 0 {
                Text(BoardCopy.layerStatus(model.currentLayerDepth))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            LayerCapsuleButton(
                title: BoardCopy.startLayer,
                systemImage: "square.3.layers.3d",
                hint: BoardCopy.startLayerHint,
                isEnabled: model.canStartLayer,
                action: {
                    model.startLayer()
                }
            )
            LayerCapsuleButton(
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

    /// 候选数开关放在蒙版控件下面，占一小行。
    private var candidatesToggle: some View {
        Toggle(BoardCopy.showCandidates, isOn: $showCandidates)
            .toggleStyle(.switch)
            .tint(AppTheme.pineGreen)
            .controlSize(.small)
            .font(.caption)
            .accessibilityHint(BoardCopy.showCandidatesHint)
    }

    /// 自动筛选和高亮行列宫两个开关并排放，小字号。
    private var filterToggles: some View {
        HStack(spacing: 16) {
            Toggle(BoardCopy.autoFilter, isOn: $model.isAutoFilterOn)
                .accessibilityHint(BoardCopy.autoFilterHint)
            Toggle(BoardCopy.highlightPeers, isOn: $highlightPeers)
                .accessibilityHint(BoardCopy.highlightPeersHint)
        }
        .toggleStyle(.switch)
        .tint(AppTheme.pineGreen)
        .controlSize(.small)
        .font(.caption)
    }

    private var solveButton: some View {
        Button {
            Task {
                await model.autoSolve()
            }
        } label: {
            solveLabel
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(model.isSolving)
        .accessibilityLabel(model.isSolving ? BoardCopy.solving : BoardCopy.autoSolve)
    }

    private var solveLabel: some View {
        // 图标在上、标题在下，和同一行的其他按钮保持一样的尺寸
        VStack(spacing: 2) {
            if model.isSolving {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "wand.and.stars")
                    .accessibilityHidden(true)
            }
            Text(BoardCopy.autoSolve)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

#Preview {
    NavigationStack {
        // 预览用替身引擎，不跑真求解
        BoardScreen(preset: .four, engine: FixtureBoardEngine())
    }
}
