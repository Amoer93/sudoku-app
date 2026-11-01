import SudokuEngine
import SwiftUI

/// 题库列表：可筛选、排序，点一行开始玩。
struct LibraryView: View {
    @Bindable var model: LibraryViewModel
    // 点击时才求解，结果放这里触发跳转
    @State private var route: PlayRoute?

    var body: some View {
        let entries = model.visibleEntries
        return Group {
            if model.isBankEmpty {
                ContentUnavailableView(
                    LibraryCopy.emptyBankTitle, systemImage: "square.grid.3x3",
                    description: Text(LibraryCopy.emptyBankHint)
                )
            } else if entries.isEmpty {
                filteredEmptyView
            } else {
                list(entries)
            }
        }
        .navigationTitle(LibraryCopy.entry)
        .toolbar { ToolbarItem(placement: .primaryAction) { filterMenu } }
        .navigationDestination(item: $route) { route in
            BoardScreen(preset: route.preset, puzzle: route.puzzle, bankEntry: route.entry).id(route.id)
        }
    }

    private func list(_ entries: [PuzzleBankEntry]) -> some View {
        List(entries) { entry in
            Button { open(entry) } label: { row(entry) }
                .buttonStyle(.plain)
        }
    }

    /// 点击后才求解（后台线程），完成再跳转；求解期间忽略重复点击（由 model 判断）。
    private func open(_ entry: PuzzleBankEntry) {
        Task {
            guard let puzzle = await model.openPuzzle(for: entry) else {
                return
            }
            route = PlayRoute(preset: .nine, puzzle: puzzle, entry: entry)
        }
    }

    /// 只是筛选没结果：给个按钮一键恢复。
    private var filteredEmptyView: some View {
        ContentUnavailableView {
            Text(LibraryCopy.emptyList)
        } actions: {
            Button(LibraryCopy.clearFilters) { model.clearFilters() }
        }
    }

    private func row(_ entry: PuzzleBankEntry) -> some View {
        HStack {
            Text(LibraryCopy.title(entry.difficulty)).font(.headline)
            if model.needsTrial(entry) {
                TrialTagView()
            }
            Spacer()
            Text(LibraryCopy.title(entry.source))
                .font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            // 被点的那一行用转圈代替箭头
            if model.openingEntryID == entry.id {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: entry.id) { await model.loadTrialFlag(for: entry) }
        .contentShape(Rectangle()) // 整行都能点
        .accessibilityElement(children: .combine)
    }

    private var filterMenu: some View {
        Menu {
            Picker(LibraryCopy.sortTitle, selection: $model.sort) {
                ForEach(LibraryCopy.sorts, id: \.self) { sort in Text(LibraryCopy.title(sort)).tag(sort) }
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
