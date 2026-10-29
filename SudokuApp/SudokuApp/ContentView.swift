import SwiftUI

/// 首页占位。棋盘、提示和图层从后续阶段开始做。
struct ContentView: View {
    var body: some View {
        NavigationStack {
            Text(HomeCopy.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding()
                .navigationTitle(HomeCopy.title)
        }
    }
}

/// 首页文案。放在这里是为了让示例测试能直接断言，不依赖界面渲染。
struct HomeCopy {
    static let title = "数独"
    static let message = "项目已搭好，玩法将在后续阶段加入。"
}

#Preview {
    ContentView()
}
