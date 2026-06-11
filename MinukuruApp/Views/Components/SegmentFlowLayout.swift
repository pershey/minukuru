import SwiftUI

struct SegmentFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 12

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let containerWidth = proposal.width ?? 320
        let rows = makeRows(in: containerWidth, subviews: subviews)
        let height = rows.reduce(CGFloat.zero) { partialResult, row in
            partialResult + row.height
        } + max(0, CGFloat(rows.count - 1)) * verticalSpacing

        return CGSize(width: containerWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(in: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for element in row.elements {
                element.view.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: element.size.width, height: element.size.height)
                )
                x += element.size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func makeRows(in width: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentElements: [FlowElement] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let itemWidth = min(size.width, width)
            let proposedWidth = currentElements.isEmpty ? itemWidth : currentWidth + horizontalSpacing + itemWidth

            if proposedWidth > width, !currentElements.isEmpty {
                rows.append(FlowRow(elements: currentElements, height: currentHeight))
                currentElements = []
                currentWidth = 0
                currentHeight = 0
            }

            currentElements.append(FlowElement(view: subview, size: CGSize(width: itemWidth, height: size.height)))
            currentWidth = currentElements.count == 1 ? itemWidth : currentWidth + horizontalSpacing + itemWidth
            currentHeight = max(currentHeight, size.height)
        }

        if !currentElements.isEmpty {
            rows.append(FlowRow(elements: currentElements, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    let elements: [FlowElement]
    let height: CGFloat
}

private struct FlowElement {
    let view: LayoutSubview
    let size: CGSize
}
