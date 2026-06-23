// Copyright © 2026 Vova Revenko

import CoreGraphics

/// Pure rectangle subdivision used by the overlay selection state machine.
public enum GridGeometry {
    public static func columnRegion(in rect: CGRect,
                                    index: Int,
                                    count: Int) -> CGRect {
        let width = rect.width / CGFloat(count)
        return CGRect(x: rect.minX + CGFloat(index) * width,
                      y: rect.minY,
                      width: width,
                      height: rect.height)
    }

    public static func rowRegion(in rect: CGRect,
                                 index: Int,
                                 count: Int) -> CGRect {
        let height = rect.height / CGFloat(count)
        return CGRect(x: rect.minX,
                      y: rect.minY + CGFloat(index) * height,
                      width: rect.width,
                      height: height)
    }

    public static func gridCell(in rect: CGRect,
                                index: Int,
                                columns: Int,
                                rows: Int) -> CGRect {
        let column = index % columns
        let row = index / columns
        let width = rect.width / CGFloat(columns)
        let height = rect.height / CGFloat(rows)
        return CGRect(x: rect.minX + CGFloat(column) * width,
                      y: rect.minY + CGFloat(row) * height,
                      width: width,
                      height: height)
    }

    public static func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }
}
