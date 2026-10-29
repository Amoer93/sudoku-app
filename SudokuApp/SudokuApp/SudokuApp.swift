import SwiftUI

/// 应用入口。引擎是静态库，已链接到 App 目标；界面从 P1 再调用。
@main
struct SudokuApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
