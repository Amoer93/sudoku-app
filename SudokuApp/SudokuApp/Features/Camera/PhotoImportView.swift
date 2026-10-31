import PhotosUI
import SwiftUI

/// 拍照导入：选图、识别、核对，然后导入成一局。
struct PhotoImportView: View {
    @State private var model = PhotoImportViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var isCameraShown = false

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
            NavigationLink {
                BoardScreen(preset: model.preset, puzzle: model.makePuzzle())
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
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            return
        }
        await load(image)
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
