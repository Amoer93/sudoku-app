import SwiftUI

/// 应用入口。棋盘目前走 App 内的引擎替身，真引擎接口合并后再换。
@main
struct SudokuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
