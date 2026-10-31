import SudokuEngine
import SwiftUI

/// 导入提示横幅的状态：显示、几秒后自动消失、点击消失。
@MainActor
@Observable
final class ImportBannerState {
    private(set) var notice: ImportNotice?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let wait: @MainActor () async throws -> Void

    /// 等待时间用闭包注入，测试里可以立刻返回。
    init(
        delay: Duration = .seconds(3),
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        wait = { try await sleep(delay) }
    }

    /// 显示提示并开始倒计时。返回倒计时任务，方便测试等它结束。
    @discardableResult
    func show(_ newNotice: ImportNotice) -> Task<Void, Never> {
        generation += 1
        let ticket = generation
        notice = newNotice
        return Task { [weak self, wait] in
            try? await wait()
            // 旧倒计时不能关掉后来显示的新提示
            if self?.generation == ticket {
                self?.dismiss()
            }
        }
    }

    /// 立刻关掉提示。
    func dismiss() {
        notice = nil
    }

    /// 重复题时，把题库里已有的那条转成可玩的题。
    func existingPuzzle() -> SamplePuzzle? {
        guard let existing = notice?.existingEntry else {
            return nil
        }
        return LibraryViewModel(bank: PuzzleBank(entries: [existing])).puzzle(for: existing)
    }
}

/// 棋盘页顶部的非阻塞横幅；点一下消失，重复题多一个“打开已有题目”按钮。
struct ImportNoticeBanner: View {
    let notice: ImportNotice
    let onOpenExisting: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(notice.text).font(.subheadline)
            if notice.existingEntry != nil {
                Button(ImportBankCopy.openExisting, action: onOpenExisting)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onTapGesture(perform: onDismiss)
    }
}
