import PhotosUI
import SwiftUI

/// 拍照导入：选图、识别、核对，然后导入成一局。
struct PhotoImportView: View {
    @State private var model = PhotoImportViewModel(importer: .shared)
    @State private var pickerItem: PhotosPickerItem?
    @State private var isCameraShown = false
    // 点“导入”时才生成题目，避免视图刷新时反复求解
    @State private var importedPuzzle: SamplePuzzle?
    @State private var isBoardShown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceButtons
                sizePicker
                if model.isLoading {
                    ProgressView(PhotoImportCopy.loading)
                }
                if let message = model.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
                if model.result != nil {
                    reviewSection
                }
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(PhotoImportCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            Task { await loadPhoto(item) }
        }
        .navigationDestination(isPresented: $isBoardShown) {
            if let puzzle = importedPuzzle {
                BoardScreen(preset: model.preset, puzzle: puzzle, notice: model.importNotice)
            }
        }
        .fullScreenCover(isPresented: $isCameraShown) {
            CameraPicker { image in
                Task { await load(image) }
            }
            .ignoresSafeArea()
        }
    }

    private var sourceButtons: some View {
        HStack {
            PhotosPicker(PhotoImportCopy.pickPhoto, selection: $pickerItem, matching: .images)
            if CameraPicker.isAvailable {
                Button(PhotoImportCopy.takePhoto) {
                    isCameraShown = true
                }
            }
        }
        .buttonStyle(.bordered)
    }

    private var sizePicker: some View {
        Picker(PhotoImportCopy.sizeLabel, selection: presetBinding) {
            ForEach(BoardPreset.allCases) { preset in
                Text(preset.title).tag(preset)
            }
        }
        .pickerStyle(.segmented)
    }

    private var presetBinding: Binding<BoardPreset> {
        Binding(
            get: { model.preset },
            set: { newPreset in
                Task { await model.changeSize(newPreset) }
            }
        )
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !model.reviewIndexes.isEmpty {
                Text(PhotoImportCopy.reviewHint).font(.footnote)
            }
            ForEach(model.messages, id: \.self) { message in
                Text(message).font(.subheadline).foregroundStyle(.red)
            }
            reviewGrid
            NumberPadView(
                size: model.grid.size,
                isEnabled: model.selectedIndex != nil,
                onDigit: { model.setDigit($0) },
                onClear: { model.clear() }
            )
            Button {
                importedPuzzle = model.confirmImport()
                isBoardShown = true
            } label: {
                Text(PhotoImportCopy.importButton).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var reviewGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: model.grid.size)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0 ..< model.grid.cells.count, id: \.self) { index in
                cellButton(index)
            }
        }
        .overlay { boxLines }
    }

    /// 在宫的边界画粗线。格子间距是 2，线落在间距中间。
    private var boxLines: some View {
        let rules = model.preset.rules
        return GeometryReader { proxy in
            Path { path in
                // 5×5 没有宫，不画
                guard let boxRows = rules.boxRows, let boxCols = rules.boxCols else {
                    return
                }
                let count = CGFloat(rules.size)
                let cellSide = (proxy.size.width - 2 * (count - 1)) / count
                for column in stride(from: boxCols, to: rules.size, by: boxCols) {
                    let xPos = CGFloat(column) * (cellSide + 2) - 1
                    path.move(to: CGPoint(x: xPos, y: 0))
                    path.addLine(to: CGPoint(x: xPos, y: proxy.size.height))
                }
                for row in stride(from: boxRows, to: rules.size, by: boxRows) {
                    let yPos = CGFloat(row) * (cellSide + 2) - 1
                    path.move(to: CGPoint(x: 0, y: yPos))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: yPos))
                }
            }
            .stroke(Color.primary, lineWidth: 3)
        }
        .allowsHitTesting(false)
    }

    private func cellButton(_ index: Int) -> some View {
        let value = model.grid.cells[index]
        return Button {
            model.selectedIndex = index
        } label: {
            Text(value == Grid.emptyCell ? "" : String(value))
                .font(.title3)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(background(for: index))
                .overlay {
                    if model.selectedIndex == index {
                        Rectangle().stroke(Color.accentColor, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// 冲突优先标红，其次是待确认的橙色。
    private func background(for index: Int) -> Color {
        if model.conflicts.contains(index) {
            return Color.red.opacity(0.3)
        }
        if model.reviewIndexes.contains(index) {
            return Color.orange.opacity(0.3)
        }
        return Color.secondary.opacity(0.1)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }
        // 清空选择，同一张照片才能再次选中
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            model.reportLoadFailure()
            return
        }
        await load(image.downscaled(maxSide: 2000))
    }

    private func load(_ image: UIImage) async {
        guard let cgImage = image.uprightCGImage() else {
            return
        }
        await model.load(image: cgImage)
    }
}

#Preview {
    NavigationStack {
        PhotoImportView()
    }
}
