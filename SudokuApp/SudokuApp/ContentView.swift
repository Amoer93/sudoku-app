import SwiftUI

/// 入口是尺寸选择。棋盘在 Features/Board。
struct ContentView: View {
    var body: some View {
        SizePickerView()
    }
}

/// 首页文案。测试直接断言这些字符串，不依赖界面渲染。
enum HomeCopy {
    static let title = "数独"
    static let message = "选一个尺寸开始。4×4 和 9×9 会画粗宫线，5×5 没有宫。"
}

#Preview {
    ContentView()
}
