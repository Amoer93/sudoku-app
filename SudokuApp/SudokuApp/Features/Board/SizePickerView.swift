import SwiftUI

/// 尺寸入口。选中后进入对应尺寸的内置题目。
struct SizePickerView: View {
    var body: some View {
        NavigationStack {
            List {
                Text(HomeCopy.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowSeparator(.hidden)
                ForEach(BoardPreset.allCases) { preset in
                    NavigationLink {
                        // 按题目区分视图身份：换题时重建 BoardScreen，模型跟着刷新
                        BoardScreen(preset: preset)
                            .id(preset)
                    } label: {
                        presetLabel(preset)
                    }
                }
                NavigationLink(PhotoImportCopy.entry) {
                    PhotoImportView()
                }
            }
            .navigationTitle(HomeCopy.title)
        }
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
