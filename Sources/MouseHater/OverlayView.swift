// Copyright © 2026 Vova Revenko

import AppKit

/// What the overlay is currently asking the user to pick.
enum OverlayMode {
    case cells([String], [String]) // 10×30: each cell labeled "column+row" (e.g. "at")
    case rows([String])            // full-width bands within the region, labels top → bottom
    case grid([String])            // 10×3, one label per cell
    case nudge(CGPoint)            // free-move: a precision cursor at a point (no dimming)
}

/// Draws the dimmed backdrop and the current selection grid. Uses a flipped
/// coordinate system (top-left origin) to match the controller's geometry.
final class OverlayView: NSView {
    var region: CGRect = .zero
    var mode: OverlayMode = .grid([])

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Nudge draws only a cursor over the live screen — no grid, no dimming.
        if case .nudge(let point) = mode {
            drawCursor(at: point)
            return
        }

        guard region.width > 0, region.height > 0 else { return }

        // Light dim everywhere, then darken outside the active region.
        NSColor(white: 0, alpha: 0.15).setFill()
        bounds.fill()
        let outside = NSBezierPath(rect: bounds)
        outside.append(NSBezierPath(rect: region))
        outside.windingRule = .evenOdd
        NSColor(white: 0, alpha: 0.30).setFill()
        outside.fill()

        switch mode {
        case .cells(let cols, let rows): drawCells(columns: cols, rows: rows)
        case .rows(let labels):          drawRows(labels)
        case .grid(let rows):            drawGrid(rows)
        case .nudge:                     break // handled by the early return above
        }

        let border = NSBezierPath(rect: region)
        border.lineWidth = 2
        NSColor.systemYellow.withAlphaComponent(0.9).setStroke()
        border.stroke()
    }

    // MARK: - Modes

    private func drawCells(columns: [String], rows: [String]) {
        let nc = columns.count, nr = rows.count
        guard nc > 0, nr > 0 else { return }
        let cellW = region.width / CGFloat(nc)
        let cellH = region.height / CGFloat(nr)
        drawGridLines(cols: nc, rows: nr)
        drawRowGroupDividers(rowCount: nr, groupSize: OverlayController.verticalRows / OverlayController.gridRows)

        let attrs = textAttributes(labelFont(for: min(cellW, cellH), maxSize: 18))
        for r in 0..<nr {
            let cy = region.minY + (CGFloat(r) + 0.5) * cellH
            for c in 0..<nc {
                let cx = region.minX + (CGFloat(c) + 0.5) * cellW
                drawLabel(columns[c] + rows[r], centeredAt: CGPoint(x: cx, y: cy), attributes: attrs)
            }
        }
    }

    private func drawRows(_ labels: [String]) {
        let n = labels.count
        guard n > 0 else { return }
        let bandH = region.height / CGFloat(n)
        drawGridLines(cols: 0, rows: n)
        drawRowGroupDividers(rowCount: n, groupSize: OverlayController.verticalRows / OverlayController.gridRows)
        let attrs = textAttributes(labelFont(for: min(region.width, bandH), maxSize: 22))
        for i in 0..<n {
            let cy = region.minY + (CGFloat(i) + 0.5) * bandH
            drawLabel(labels[i], centeredAt: CGPoint(x: region.midX, y: cy), attributes: attrs)
        }
    }

    private func drawGrid(_ rows: [String]) {
        let cols = OverlayController.columns
        let rowCount = OverlayController.gridRows
        let cellW = region.width / CGFloat(cols)
        let cellH = region.height / CGFloat(rowCount)
        drawGridLines(cols: cols, rows: rowCount)
        let attrs = textAttributes(labelFont(for: min(cellW, cellH), maxSize: 34))
        for r in 0..<rowCount where r < rows.count {
            let chars = Array(rows[r])
            for c in 0..<cols where c < chars.count {
                let cx = region.minX + (CGFloat(c) + 0.5) * cellW
                let cy = region.minY + (CGFloat(r) + 0.5) * cellH
                drawLabel(String(chars[c]), centeredAt: CGPoint(x: cx, y: cy), attributes: attrs)
            }
        }
    }

    // MARK: - Drawing helpers

    /// A precision target marker: a gapped crosshair plus a centre dot, each
    /// drawn with a dark outline so it reads on any background.
    private func drawCursor(at p: CGPoint) {
        let arm: CGFloat = 9, gap: CGFloat = 3
        let cross = NSBezierPath()
        cross.move(to: CGPoint(x: p.x - arm, y: p.y)); cross.line(to: CGPoint(x: p.x - gap, y: p.y))
        cross.move(to: CGPoint(x: p.x + gap, y: p.y)); cross.line(to: CGPoint(x: p.x + arm, y: p.y))
        cross.move(to: CGPoint(x: p.x, y: p.y - arm)); cross.line(to: CGPoint(x: p.x, y: p.y - gap))
        cross.move(to: CGPoint(x: p.x, y: p.y + gap)); cross.line(to: CGPoint(x: p.x, y: p.y + arm))

        NSColor.black.withAlphaComponent(0.65).setStroke()
        cross.lineWidth = 2.5
        cross.stroke()
        NSColor.systemYellow.setStroke()
        cross.lineWidth = 1
        cross.stroke()

        let r: CGFloat = 2
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(ovalIn: CGRect(x: p.x - r - 1, y: p.y - r - 1, width: 2 * (r + 1), height: 2 * (r + 1))).fill()
        NSColor.systemYellow.setFill()
        NSBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
    }

    private func drawGridLines(cols: Int, rows: Int) {
        NSColor(white: 1, alpha: 0.18).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        if cols > 0 {
            let w = region.width / CGFloat(cols)
            for c in 0...cols {
                let x = region.minX + CGFloat(c) * w
                path.move(to: CGPoint(x: x, y: region.minY))
                path.line(to: CGPoint(x: x, y: region.maxY))
            }
        }
        if rows > 0 {
            let h = region.height / CGFloat(rows)
            for r in 0...rows {
                let y = region.minY + CGFloat(r) * h
                path.move(to: CGPoint(x: region.minX, y: y))
                path.line(to: CGPoint(x: region.maxX, y: y))
            }
        }
        path.stroke()
    }

    /// Subtly emphasises the boundaries between groups of `groupSize` rows, so
    /// the 30 rows read as three blocks matching the keyboard rows
    /// (q–p / a–; / z–/).
    private func drawRowGroupDividers(rowCount: Int, groupSize: Int) {
        guard groupSize > 0, rowCount > groupSize else { return }
        let h = region.height / CGFloat(rowCount)
        NSColor(white: 1, alpha: 0.55).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1.5
        var r = groupSize
        while r < rowCount {
            let y = region.minY + CGFloat(r) * h
            path.move(to: CGPoint(x: region.minX, y: y))
            path.line(to: CGPoint(x: region.maxX, y: y))
            r += groupSize
        }
        path.stroke()
    }

    private func drawLabel(_ string: String, centeredAt point: CGPoint, attributes: [NSAttributedString.Key: Any]) {
        let text = NSAttributedString(string: string, attributes: attributes)
        let size = text.size()
        let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
        let pad: CGFloat = 3
        let pill = CGRect(x: origin.x - pad, y: origin.y - pad,
                          width: size.width + pad * 2, height: size.height + pad * 2)
        let radius = min(pill.width, pill.height) * 0.3
        NSColor(white: 0, alpha: 0.55).setFill()
        NSBezierPath(roundedRect: pill, xRadius: radius, yRadius: radius).fill()
        text.draw(at: origin)
    }

    private func labelFont(for dimension: CGFloat, maxSize: CGFloat) -> NSFont {
        let size = max(8, min(dimension * 0.45, maxSize))
        return NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    private func textAttributes(_ font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: NSColor.white]
    }
}
