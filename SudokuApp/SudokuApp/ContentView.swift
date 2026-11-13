import SwiftUI

/// 入口是尺寸选择。棋盘在 Features/Board。
struct ContentView: View {
    // 整个 App 共用一份进度，棋盘页通过环境读取
    @State private var progress = PuzzleProgressModel()

    var body: some View {
        SizePickerView()
            .environment(progress)
    }
}

/// 首页文案。测试直接断言这些字符串，不依赖界面渲染。
enum HomeCopy {
    static let title = "数独"
    static let message = ProgressCopy.intro
}

#Preview {
    ContentView()
}
