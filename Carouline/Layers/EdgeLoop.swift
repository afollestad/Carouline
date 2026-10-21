//
//  EdgeLoop.swift
//  Carouline
//

import CoreGraphics
import Foundation

/// A closed loop a border's edge is cut into, its filled side on the right of the way it runs on
/// screen, split into runs that each take a whole number of a regular pattern's teeth, and any
/// corners rounded between them.
nonisolated struct EdgeLoop {
    let runs: [EdgeRun]
    let length: CGFloat

    /// `rect`'s sides, clockwise from its top left, a run each, so teeth land alike on its corners,
    /// and its corners rounded to `cornerRadius` by uncut runs between them.
    init(rect: CGRect, cornerRadius: CGFloat = 0) {
        let radius = min(cornerRadius, rect.width / 2, rect.height / 2)
        // Each corner's center and the angle its arc starts at, turning clockwise on screen.
        let corners = [
            (CGPoint(x: rect.minX + radius, y: rect.minY + radius), CGFloat.pi),
            (CGPoint(x: rect.maxX - radius, y: rect.minY + radius), -CGFloat.pi / 2),
            (CGPoint(x: rect.maxX - radius, y: rect.maxY - radius), 0),
            (CGPoint(x: rect.minX + radius, y: rect.maxY - radius), CGFloat.pi / 2)
        ]
        var runs: [EdgeRun] = []
        for (index, corner) in corners.enumerated() {
            let arc = (0...16).map { step in
                let angle = corner.1 + CGFloat(step) * .pi / 32
                return CGPoint(x: corner.0.x + radius * cos(angle), y: corner.0.y + radius * sin(angle))
            }
            if radius > 0 {
                runs.append(EdgeRun(points: arc, isCut: false))
            }
            let next = corners[(index + 1) % corners.count]
            let nextStart = CGPoint(x: next.0.x + radius * cos(next.1), y: next.0.y + radius * sin(next.1))
            runs.append(EdgeRun(points: [arc[arc.count - 1], nextStart], isCut: true))
        }
        self.init(runs: runs)
    }

    /// `runs` in order around a loop, each starting where the one before ends.
    init(runs: [EdgeRun]) {
        var runs = runs
        for index in runs.indices {
            let previous = runs[(index + runs.count - 1) % runs.count]
            runs[index].setCorner(after: previous)
        }
        self.runs = runs
        length = runs.reduce(0) { $0 + $1.length }
    }
}

/// A point on a loop, the way in from it, and how deep the edge is cut there.
nonisolated struct EdgePoint {
    let base: CGPoint
    let normal: CGPoint
    let depth: CGFloat

    /// Where the cut edge runs.
    var point: CGPoint {
        base + normal * depth
    }

    /// `extra` further in than the cut edge.
    func inset(by extra: CGFloat) -> CGPoint {
        base + normal * (depth + extra)
    }
}

/// A stretch of a loop from one point to another through those between.
nonisolated struct EdgeRun {
    let points: [CGPoint]
    /// Whether a regular pattern's teeth are cut into it, rather than it rounding a corner between
    /// them. Noise cuts every run alike.
    let isCut: Bool
    /// The distance along the run to each point.
    let distances: [CGFloat]
    /// The way in from its first point where it turns a sharp corner from the run before: both
    /// sides' ways in at once, so a cut there moves the corner in from both sides as deep as it
    /// cuts each, rather than leaving a sliver standing out along one.
    private(set) var cornerNormal: CGPoint?

    init(points: [CGPoint], isCut: Bool) {
        self.points = points
        self.isCut = isCut
        var distances: [CGFloat] = [0]
        for index in points.indices.dropFirst() {
            distances.append(distances[index - 1] + (points[index] - points[index - 1]).length)
        }
        self.distances = distances
    }

    var length: CGFloat {
        distances.last ?? 0
    }

    mutating func setCorner(after previous: EdgeRun) {
        let from = previous.normal(ofSegment: previous.points.count - 2)
        let into = normal(ofSegment: 0)
        let alignment = from.x * into.x + from.y * into.y
        // The way that moves the corner one in along each side's way in. A side turning right
        // back on itself has none.
        cornerNormal = alignment < 0.9999 && alignment > -0.99 ? (from + into) * (1 / (1 + alignment)) : nil
    }

    /// The run's points and ways in at `distances` along it, which rise, cut `depth` deep at each.
    func points(at distances: [CGFloat], depth: (Int) -> CGFloat) -> [EdgePoint] {
        var segment = 0
        return distances.enumerated().map { index, distance in
            while segment < points.count - 2, distance >= self.distances[segment + 1] {
                segment += 1
            }
            let start = points[segment]
            let span = points[segment + 1] - start
            let spanLength = span.length
            let share = spanLength > 0 ? (distance - self.distances[segment]) / spanLength : 0
            let normal = distance == 0 ? cornerNormal ?? normal(ofSegment: segment) : normal(ofSegment: segment)
            return EdgePoint(base: start + span * share, normal: normal, depth: depth(index))
        }
    }

    /// The way in from a segment, a unit long: on a screen running down, the way it goes turned a
    /// quarter clockwise, since the filled side is on its right.
    private func normal(ofSegment segment: Int) -> CGPoint {
        guard segment >= 0, segment + 1 < points.count else {
            return .zero
        }
        let span = points[segment + 1] - points[segment]
        let spanLength = span.length
        return spanLength > 0 ? CGPoint(x: -span.y / spanLength, y: span.x / spanLength) : .zero
    }
}

/// How rough an irregular edge is: as deep as `depth` at most, its largest features `feature`
/// long, both shares of the edge's size, with `octaves` of finer features, each half as long and
/// half as strong.
nonisolated struct Roughness: Sendable {
    let depth: CGFloat
    let feature: CGFloat
    let octaves: Int
    /// Whether it eases between its values, rather than running straight between them in sharp
    /// little tears.
    let isSmooth: Bool
    /// How far values spread out from the middle, where a sum of octaves crowds them.
    let contrast: CGFloat
    /// How round a rectangle's corners are, as a share of the edge's size: further than anything
    /// reaches in from its edge, so cuts from either side, offset along ways in that turn with the
    /// corner, never cross there in slivers.
    var cornerRadius: CGFloat = 0
}

/// Value noise around a loop from 0 to 1, wrapping at its end.
nonisolated struct EdgeNoise {
    private let octaves: [[CGFloat]]
    private let roughness: Roughness

    init(_ roughness: Roughness, length: CGFloat, size: CGFloat, generator: inout SeededGenerator) {
        var feature = roughness.feature * size
        var octaves: [[CGFloat]] = []
        for _ in 0..<roughness.octaves {
            let values = max(3, Int((length / feature).rounded()))
            octaves.append((0..<values).map { _ in generator.nextUnit() })
            feature /= 2
        }
        self.octaves = octaves
        self.roughness = roughness
    }

    /// The noise `position` of the way around the loop.
    func value(at position: CGFloat) -> CGFloat {
        var total: CGFloat = 0
        var weight: CGFloat = 0
        var amplitude: CGFloat = 1
        for values in octaves {
            let scaled = position * CGFloat(values.count)
            let index = Int(scaled.rounded(.down))
            var share = scaled - CGFloat(index)
            if roughness.isSmooth {
                share = share * share * (3 - 2 * share)
            }
            let from = values[index.wrapped(to: values.count)]
            let next = values[(index + 1).wrapped(to: values.count)]
            total += amplitude * (from + (next - from) * share)
            weight += amplitude
            amplitude /= 2
        }
        let value = weight > 0 ? total / weight : 0
        return min(max(0.5 + (value - 0.5) * roughness.contrast, 0), 1)
    }
}

/// SplitMix64: the same numbers from the same seed on every device and every launch, which
/// `SystemRandomNumberGenerator` and `Hasher` never give, so a layer's edge stays as it was.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UUID) {
        state = withUnsafeBytes(of: seed.uuid) { bytes in
            bytes.loadUnaligned(as: UInt64.self) ^ bytes.loadUnaligned(fromByteOffset: 8, as: UInt64.self)
        }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// A number from 0 up to 1, from the top 53 bits, which a `Double` holds exactly.
    mutating func nextUnit() -> CGFloat {
        CGFloat(next() >> 11) * 0x1p-53
    }
}

nonisolated private extension Int {
    /// This index wrapped around a loop of `count`, behind its start too.
    func wrapped(to count: Int) -> Int {
        ((self % count) + count) % count
    }
}

nonisolated extension CGPoint {
    fileprivate var length: CGFloat {
        hypot(x, y)
    }

    fileprivate static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    fileprivate static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    fileprivate static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}
