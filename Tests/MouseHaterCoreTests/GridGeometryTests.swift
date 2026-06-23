// Copyright © 2026 Vova Revenko

import CoreGraphics
import XCTest
@testable import MouseHaterCore

final class GridGeometryTests: XCTestCase {
    func testColumnSubdivisionPreservesNegativeDisplayOrigin() {
        let display = CGRect(x: -1920, y: 100, width: 1500, height: 900)

        let column = GridGeometry.columnRegion(in: display, index: 9, count: 10)

        XCTAssertEqual(column, CGRect(x: -570, y: 100, width: 150, height: 900))
    }

    func testLastRowEndsAtRegionMaximum() {
        let display = CGRect(x: -1920, y: 100, width: 1500, height: 900)

        let row = GridGeometry.rowRegion(in: display, index: 29, count: 30)

        XCTAssertEqual(row.minY, 970, accuracy: 0.0001)
        XCTAssertEqual(row.maxY, display.maxY, accuracy: 0.0001)
    }

    func testGridCellUsesReadingOrder() {
        let region = CGRect(x: -100, y: -200, width: 1000, height: 300)

        let cell = GridGeometry.gridCell(in: region, index: 29, columns: 10, rows: 3)

        XCTAssertEqual(cell, CGRect(x: 800, y: 0, width: 100, height: 100))
        XCTAssertEqual(GridGeometry.center(of: cell), CGPoint(x: 850, y: 50))
    }
}
