import SwiftUI

/// 棋盘格子和宫线。线的粗细由 BoardLines 决定，这里只负责画。
struct BoardGridView: View {
    let rules: Rules
    let cells: [BoardCellState]
    let onSelect: (Int) -> Void

    @ScaledMetric(relativeTo: .title) private var typeScale: CGFloat = 1

    var body: some View {
        if rules.size > 0 {
            square
        } else {
            Text(BoardCopy.invalidSize)
                .font(.body)
                .foregroundStyle(.red)
        }
    }

    private var square: some View {
        Color.clear
            .accessibilityHidden(true)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    board(side: side)
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(4)
            .accessibilityElement(children: .contain)
    }

    private func board(side: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(AppTheme.boardCell)
            cellsLayer(side: side)
            lineLayer(side: side)
        }
        // 格子和线一起裁成圆角，四个角才干净
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.boardCornerRadius))
        .frame(width: side, height: side, alignment: .topLeading)
    }

    private func cellsLayer(side: CGFloat) -> some View {
        let cellSide = side / CGFloat(rules.size)
        // 模型也叫 Grid，这里要写成 SwiftUI.Grid，避免和棋盘数据撞名。
        return SwiftUI.Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(0 ..< rules.size, id: \.self) { row in
                GridRow {
                    ForEach(0 ..< rules.size, id: \.self) { column in
                        cellAt(row: row, column: column, side: cellSide)
                    }
                }
            }
        }
        .frame(width: side, height: side, alignment: .topLeading)
    }

    /// 用真实布局放格子，点按区域才和看到的位置一致。
    @ViewBuilder
    private func cellAt(row: Int, column: Int, side: CGFloat) -> some View {
        let index = row * rules.size + column
        if cells.indices.contains(index) {
            cellView(cells[index], side: side)
        } else {
            Color.clear.frame(width: side, height: side)
        }
    }

    private func cellView(_ cell: BoardCellState, side: CGFloat) -> some View {
        Button {
            onSelect(cell.index)
        } label: {
            cellLabel(cell, side: side)
        }
        .buttonStyle(.plain)
        .frame(width: side, height: side)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityAddTraits(traits(for: cell))
    }

    private func cellLabel(_ cell: BoardCellState, side: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(fill(for: cell))
            if cell.isPeerHighlighted, hasLayerTint(cell) {
                // 蒙版格保留本层底色，只叠一层淡色；普通格直接换成 peerHighlight
                Rectangle().fill(Color.primary.opacity(peerOverlayOpacity(for: cell)))
            }
            if cell.isSelected {
                // 选中用内侧描边，不用发光或阴影
                Rectangle().strokeBorder(AppTheme.pineGreen, lineWidth: AppTheme.selectedStrokeWidth)
            }
            candidateGrid(for: cell, side: side)
            Text(cell.value == 0 ? "" : String(cell.value))
                .font(digitFont(for: cell, side: side))
                .foregroundStyle(textColor(for: cell))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
    }

    /// 候选数画成 3x3 小格；数字 n 放在第 (n-1)/3 行、(n-1)%3 列。
    @ViewBuilder
    private func candidateGrid(for cell: BoardCellState, side: CGFloat) -> some View {
        if cell.value == 0, !cell.candidates.isEmpty {
            let miniSide = side / 3
            VStack(spacing: 0) {
                ForEach(0 ..< 3, id: \.self) { miniRow in
                    HStack(spacing: 0) {
                        ForEach(0 ..< 3, id: \.self) { miniColumn in
                            let digit = miniRow * 3 + miniColumn + 1
                            Text(cell.candidates.contains(digit) ? String(digit) : "")
                                .font(.system(size: max(miniSide * 0.7, 1), design: .rounded))
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: miniSide, height: miniSide)
                        }
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func lineLayer(side: CGFloat) -> some View {
        Canvas { context, size in
            drawLines(in: &context, size: size)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    /// 先画细线，再画外框和宫线，交叉处就不会被细线盖住。
    private func drawLines(in context: inout GraphicsContext, size: CGSize) {
        let step = size.width / CGFloat(rules.size)
        strokePass(in: &context, size: size, step: step, thick: false)
        strokePass(in: &context, size: size, step: step, thick: true)
    }

    private func strokePass(in context: inout GraphicsContext, size: CGSize, step: CGFloat, thick: Bool) {
        for line in 0 ... rules.size {
            stroke(in: &context, size: size, step: step, line: line, vertical: true, thick: thick)
            stroke(in: &context, size: size, step: step, line: line, vertical: false, thick: thick)
        }
    }

    private func stroke(
        in context: inout GraphicsContext,
        size: CGSize,
        step: CGFloat,
        line: Int,
        vertical: Bool,
        thick: Bool
    ) {
        let weight = lineWeight(line: line, vertical: vertical)
        let isThick = weight != .hairline
        guard isThick == thick else {
            return
        }
        let width = CGFloat(weight.points)
        let path = linePath(size: size, step: step, line: line, vertical: vertical, lineWidth: width)
        context.stroke(path, with: .color(color(for: weight)), lineWidth: width)
    }

    private func linePath(
        size: CGSize,
        step: CGFloat,
        line: Int,
        vertical: Bool,
        lineWidth: CGFloat
    ) -> Path {
        let limit = vertical ? size.width : size.height
        let position = coordinate(line, step: step, limit: limit, lineWidth: lineWidth)
        var path = Path()
        if vertical {
            path.move(to: CGPoint(x: position, y: 0))
            path.addLine(to: CGPoint(x: position, y: size.height))
        } else {
            path.move(to: CGPoint(x: 0, y: position))
            path.addLine(to: CGPoint(x: size.width, y: position))
        }
        return path
    }

    private func lineWeight(line: Int, vertical: Bool) -> BoardLineWeight {
        if vertical {
            return BoardLines.verticalWeight(line: line, rules: rules)
        }
        return BoardLines.horizontalWeight(line: line, rules: rules)
    }

    /// 外框往里收半个线宽，避免被父视图裁掉。
    private func coordinate(_ line: Int, step: CGFloat, limit: CGFloat, lineWidth: CGFloat) -> CGFloat {
        let raw = CGFloat(line) * step
        let half = lineWidth / 2
        return min(max(raw, half), max(limit - half, half))
    }

    private func color(for weight: BoardLineWeight) -> Color {
        switch weight {
        case .hairline:
            return AppTheme.thinLine
        case .frame, .box:
            return AppTheme.boxLine
        }
    }

    /// 非题目格带着蒙版（试填）底色。
    private func hasLayerTint(_ cell: BoardCellState) -> Bool {
        return AssumptionLayerStyle.tintColor(forDepth: cell.layerDepth) != nil && !cell.isGiven
    }

    private func fill(for cell: BoardCellState) -> Color {
        if cell.isConflict {
            // 选中与否底色都一样，选中靠描边表示
            return AppTheme.conflictBackground
        }
        if cell.isHinted, cell.isAssumptionHint {
            // 假设格用青色，和确定格的金色一眼分得开（试填层，之后再改）
            return Color.teal.opacity(0.4)
        }
        if cell.isHinted {
            return AppTheme.hintGoldBackground
        }
        if cell.isSelected {
            return AppTheme.pineFill
        }
        // 选中和提示优先；其余蒙版格用本层的淡底色
        if let tint = AssumptionLayerStyle.tintColor(forDepth: cell.layerDepth), !cell.isGiven {
            return tint
        }
        if cell.isPeerHighlighted {
            return AppTheme.peerHighlight
        }
        return AppTheme.boardCell
    }

    /// 有蒙版底色的格子叠得更淡，免得盖掉本层颜色。
    private func peerOverlayOpacity(for cell: BoardCellState) -> Double {
        return hasLayerTint(cell) ? BoardHighlightStyle.tintedPeerOverlay : BoardHighlightStyle.peerOverlay
    }

    private func textColor(for cell: BoardCellState) -> Color {
        if cell.isConflict || cell.isGiven {
            return AppTheme.primaryText
        }
        if cell.isHinted, !cell.isAssumptionHint {
            return AppTheme.hintGoldText
        }
        if let style = AssumptionLayerStyle.style(forDepth: cell.layerDepth) {
            return style.color
        }
        return AppTheme.pineGreen
    }

    private func digitFont(for cell: BoardCellState, side: CGFloat) -> Font {
        let baseSize = cell.isGiven ? AppTheme.givenDigitSize : AppTheme.userDigitSize
        let weight = cell.isGiven ? AppTheme.givenDigitWeight : AppTheme.userDigitWeight
        return .system(size: fontSize(base: baseSize, cellSide: side), weight: weight, design: .rounded)
    }

    /// 动态字体放大时数字跟着变大，但不超过格子的 70%，小格子（9×9）也放得下。
    private func fontSize(base: CGFloat, cellSide: CGFloat) -> CGFloat {
        let scaled = base * min(typeScale, 1.8)
        return max(min(scaled, cellSide * 0.7), 1)
    }

    private func traits(for cell: BoardCellState) -> AccessibilityTraits {
        if cell.isSelected {
            return .isSelected
        }
        return []
    }
}
