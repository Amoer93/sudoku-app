import SudokuEngine
import SwiftUI

/// 尺寸入口。选中后进入对应尺寸的内置题目。
struct SizePickerView: View {
    @State private var library = LibraryViewModel(bank: PuzzleBankStore().load())
    @State private var difficulty: Difficulty = .easy

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
                if !library.hasEntries(difficulty: difficulty) {
                    Text(LibraryCopy.difficultyFallback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(BoardPreset.allCases) { preset in
                    NavigationLink {
                        // 按题目区分视图身份：换题时重建 BoardScreen，模型跟着刷新
                        BoardScreen(preset: preset, puzzle: startingPuzzle(for: preset))
                            .id(preset)
                    } label: {
                        presetLabel(preset)
                    }
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
        }
    }

    /// 重新读文件，让刚导入的题能被看到。
    private func reloadLibrary() {
        library.reload(PuzzleBankStore().load())
    }

    /// 9×9 按所选难度从题库抽题；抽不到或其他尺寸就用内置题
    private func startingPuzzle(for preset: BoardPreset) -> SamplePuzzle? {
        guard preset == .nine else { return nil }
        return library.newGamePuzzle(difficulty: difficulty)
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
