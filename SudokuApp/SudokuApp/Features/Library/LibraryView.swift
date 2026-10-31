import SwiftUI

/// 题库列表：可筛选、排序，点一行开始玩。
struct LibraryView: View {
    @Bindable var model: LibraryViewModel

    var body: some View {
        List {
            ForEach(model.visibleEntries) { entry in
                NavigationLink {
                    BoardScreen(preset: .nine, puzzle: model.puzzle(for: entry)).id(entry.id)
                } label: {
                    row(entry)
                }
            }
            if model.visibleEntries.isEmpty {
                Text(LibraryCopy.emptyList).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(LibraryCopy.entry)
        .toolbar { ToolbarItem(placement: .primaryAction) { filterMenu } }
    }

    private func row(_ entry: PuzzleBankEntry) -> some View {
        HStack {
            Text(LibraryCopy.title(entry.difficulty)).font(.headline)
            Spacer()
            Text(LibraryCopy.title(entry.source))
                .font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private var filterMenu: some View {
        Menu {
            Picker(LibraryCopy.sortTitle, selection: $model.sort) {
                ForEach(PuzzleBankSort.allCases, id: \.self) { sort in Text(LibraryCopy.title(sort)).tag(sort) }
            }
            Picker(LibraryCopy.difficultyTitle, selection: $model.difficultyFilter) {
                Text(LibraryCopy.all).tag(Difficulty?.none)
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    Text(LibraryCopy.title(difficulty)).tag(Difficulty?.some(difficulty))
                }
            }
            Picker(LibraryCopy.sourceTitle, selection: $model.sourceFilter) {
                Text(LibraryCopy.all).tag(PuzzleSource?.none)
                ForEach(PuzzleSource.allCases, id: \.self) { source in
                    Text(LibraryCopy.title(source)).tag(PuzzleSource?.some(source))
                }
            }
        } label: {
            Label(LibraryCopy.sortMenu, systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}
