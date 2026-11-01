import SudokuEngine
import SwiftUI

/// 尺寸入口。选中后进入对应尺寸的内置题目。
struct SizePickerView: View {
    @State private var library = LibraryViewModel(bank: PuzzleBankStore().load())
    @State private var difficulty: Difficulty = .easy
    // 点击时选一次题，避免视图刷新时反复抽题、求解
    @State private var route: PlayRoute?
    @State private var isOpening = false

    var body: some View {
        NavigationStack {
            List {
                Text(HomeCopy.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowSeparator(.hidden)
                Picker(LibraryCopy.difficultyTitle, selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in Text(LibraryCopy.title(level)).tag(level) }
                }
                .pickerStyle(.segmented)
                // 分段控件放不下副标题，所以选中专家时在下面显示一行
                if let subtitle = TrialTagCopy.pickerSubtitle(for: difficulty) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel(TrialTagCopy.accessibilityLabel)
                }
                if !library.hasEntries(difficulty: difficulty) {
                    Text(LibraryCopy.difficultyFallback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(BoardPreset.allCases) { preset in
                    Button { open(preset) } label: { presetLabel(preset) }
                        .buttonStyle(.plain)
                }
                NavigationLink(LibraryCopy.entry) {
                    LibraryView(model: library).onAppear(perform: reloadLibrary)
                }
                NavigationLink(PhotoImportCopy.entry) {
                    PhotoImportView()
                }
            }
            .navigationTitle(HomeCopy.title)
            .onAppear(perform: reloadLibrary)
            .navigationDestination(item: $route) { route in
                // 每次点击一个新 id：换题时重建 BoardScreen，模型跟着刷新
                BoardScreen(preset: route.preset, puzzle: route.puzzle, bankEntry: route.entry).id(route.id)
            }
        }
    }

    /// 点击时才选题（只选一次）；9×9 的求解在后台做，完成后再跳转。
    private func open(_ preset: BoardPreset) {
        guard !isOpening else {
            return
        }
        isOpening = true
        Task {
            let draw = await startingDraw(for: preset)
            route = PlayRoute(preset: preset, puzzle: draw?.puzzle, entry: draw?.entry)
            isOpening = false
        }
    }

    /// 重新读文件，让刚导入的题能被看到。
    private func reloadLibrary() {
        library.reload(PuzzleBankStore().load())
    }

    /// 9×9 按所选难度从题库抽题；抽不到或其他尺寸就用内置题
    private func startingDraw(for preset: BoardPreset) async -> (entry: PuzzleBankEntry, puzzle: SamplePuzzle)? {
        guard preset == .nine else { return nil }
        return await library.newGameDrawAsync(difficulty: difficulty)
    }

    private func presetLabel(_ preset: BoardPreset) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.title)
                .font(.headline)
            Text(preset.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SizePickerView()
}
