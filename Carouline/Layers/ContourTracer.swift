//
//  ContourTracer.swift
//  Carouline
//

import CoreGraphics
import Foundation

/// Traces where a field of values crosses a level, by marching squares, as closed loops a cut
/// edge can run along.
nonisolated enum ContourTracer {
    /// `values`, `width` by `height` from the top left, traced at `level`: loops of positions in
    /// pixels from the field's top left, each with the field above the level on its right as it
    /// runs on screen, simplified to within `tolerance` pixels. A border of zeros around the field
    /// closes loops that reach its edge.
    static func loops(in values: [Float], width: Int, height: Int, level: Float, tolerance: CGFloat) -> [[CGPoint]] {
        let grid = Grid(values: values, width: width, height: height, level: level)
        var next: [Int: Int] = [:]
        // In the order the grid's read, so each loop starts at its first crossing that way, the
        // same on every launch, as a dictionary's own order isn't. A cut's pattern starts there.
        var starts: [Int] = []
        for row in 0..<(grid.rows - 1) {
            for column in 0..<(grid.columns - 1) {
                for (from, into) in grid.segments(column: column, row: row) {
                    next[from] = into
                    starts.append(from)
                }
            }
        }
        var loops: [[CGPoint]] = []
        for start in starts where next[start] != nil {
            var loop: [CGPoint] = []
            var edge = start
            while let following = next.removeValue(forKey: edge) {
                loop.append(grid.point(on: edge))
                edge = following
            }
            let simplified = simplify(loop, tolerance: tolerance)
            if simplified.count >= 3 {
                loops.append(simplified)
            }
        }
        return loops
    }

    /// `loop` with every point dropped that lies within `tolerance` of the line between those kept
    /// either side of it, by Douglas–Peucker, starting from its first point.
    static func simplify(_ loop: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard loop.count > 3, let first = loop.first else {
            return loop
        }
        let points = loop + [first]
        var isKept = [Bool](repeating: false, count: points.count)
        isKept[0] = true
        isKept[points.count - 1] = true
        var spans = [(0, points.count - 1)]
        while let (start, end) = spans.popLast() {
            var farthest = start
            var distance: CGFloat = 0
            for index in (start + 1)..<max(start + 1, end) {
                let away = Self.distance(of: points[index], from: points[start], to: points[end])
                if away > distance {
                    farthest = index
                    distance = away
                }
            }
            if distance > tolerance {
                isKept[farthest] = true
                spans.append((start, farthest))
                spans.append((farthest, end))
            }
        }
        return points.indices.dropLast().filter { isKept[$0] }.map { points[$0] }
    }

    /// How far `point` is from the segment between `start` and `end`.
    private static func distance(of point: CGPoint, from start: CGPoint, to end: CGPoint) -> CGFloat {
        let along = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let lengthSquared = along.x * along.x + along.y * along.y
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let share = min(max(((point.x - start.x) * along.x + (point.y - start.y) * along.y) / lengthSquared, 0), 1)
        return hypot(point.x - start.x - share * along.x, point.y - start.y - share * along.y)
    }
}

/// A field's values at the corners of a grid of cells, with a border of zeros round it, and the
/// edges between corners, numbered two to a corner: the one across from it, then the one down.
nonisolated private struct Grid {
    let columns: Int
    let rows: Int
    private let values: [Float]
    private let width: Int
    private let height: Int
    private let level: Float

    /// The segments crossing a cell in each case of which of its corners are above the level,
    /// top left 8, top right 4, bottom right 2 and bottom left 1, between its edges numbered top,
    /// right, bottom and left, each running with the corners above the level on its right. Cases
    /// 5 and 10, a saddle, take theirs from the cell's middle.
    private static let segments: [[(Int, Int)]] = [
        [], [(3, 2)], [(2, 1)], [(3, 1)], [(1, 0)], [], [(2, 0)], [(3, 0)],
        [(0, 3)], [(0, 2)], [], [(0, 1)], [(1, 3)], [(1, 2)], [(2, 3)], []
    ]

    init(values: [Float], width: Int, height: Int, level: Float) {
        self.values = values
        self.width = width
        self.height = height
        self.level = level
        columns = width + 2
        rows = height + 2
    }

    /// The field at a corner, counting the border of zeros round it.
    private func value(column: Int, row: Int) -> Float {
        let x = column - 1
        let y = row - 1
        guard x >= 0, y >= 0, x < width, y < height else {
            return 0
        }
        return values[y * width + x]
    }

    /// The cell's segments from one edge to another, by the edges' numbers.
    func segments(column: Int, row: Int) -> [(Int, Int)] {
        let topLeft = value(column: column, row: row)
        let topRight = value(column: column + 1, row: row)
        let bottomRight = value(column: column + 1, row: row + 1)
        let bottomLeft = value(column: column, row: row + 1)
        let index = (topLeft > level ? 8 : 0) | (topRight > level ? 4 : 0) | (bottomRight > level ? 2 : 0) | (bottomLeft > level ? 1 : 0)
        // Most cells lie wholly in or out, so they return before building anything.
        guard index != 0, index != 15 else {
            return []
        }
        let isMiddleAbove = (topLeft + topRight + bottomRight + bottomLeft) / 4 > level
        let cases = switch index {
        case 5: isMiddleAbove ? [(3, 0), (1, 2)] : [(1, 0), (3, 2)]
        case 10: isMiddleAbove ? [(0, 1), (2, 3)] : [(0, 3), (2, 1)]
        default: Self.segments[index]
        }
        let edges = [
            edge(column: column, row: row, isDown: false),
            edge(column: column + 1, row: row, isDown: true),
            edge(column: column, row: row + 1, isDown: false),
            edge(column: column, row: row, isDown: true)
        ]
        return cases.map { (edges[$0.0], edges[$0.1]) }
    }

    private func edge(column: Int, row: Int, isDown: Bool) -> Int {
        (row * columns + column) * 2 + (isDown ? 1 : 0)
    }

    /// Where the field crosses the level along `edge`, in pixels from the field's top left, its
    /// corners at the pixels' middles.
    func point(on edge: Int) -> CGPoint {
        let corner = edge / 2
        let column = corner % columns
        let row = corner / columns
        let isDown = edge % 2 == 1
        let from = value(column: column, row: row)
        let toward = isDown ? value(column: column, row: row + 1) : value(column: column + 1, row: row)
        let share = toward == from ? 0.5 : CGFloat((level - from) / (toward - from))
        return CGPoint(
            x: CGFloat(column) - 0.5 + (isDown ? 0 : share),
            y: CGFloat(row) - 0.5 + (isDown ? share : 0)
        )
    }
}
