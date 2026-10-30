import SwiftUI

/// 尺寸入口。选中后进入对应的示例棋盘。
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
                        BoardScreen(preset: preset)
                    } label: {
                        presetLabel(preset)
                    }
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
