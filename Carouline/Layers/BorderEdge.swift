//
//  BorderEdge.swift
//  Carouline
//

import CoreGraphics
import Foundation

/// A border's shape with its style's edge cut in, built once at a reference size and drawn scaled
/// by `LayerRenderer.drawEdge`, so the screen and the export draw the same teeth at any size.
/// Immutable, so safe to share across threads.
nonisolated final class StyledEdge: @unchecked Sendable {
    /// What's filled: the shape with its edge cut in, less a rubber stamp's specks.
    let fill: CGPath
    /// A burnt edge's char, its bands filled over the fill in order.
    let char: [CharBand]
    /// The box it was built in, which a draw scales onto the layer's.
    let bounds: CGRect

    init(fill: CGPath, char: [CharBand], bounds: CGRect) {
        self.fill = fill
        self.char = char
        self.bounds = bounds
    }
}

/// A band of a burnt edge's char: the region between the cut edge and a ragged line in from it,
/// which runs the other way, so the nonzero rule fills between them even where the line, reaching
/// in past a corner's curve, crosses itself there.
nonisolated struct CharBand {
    let path: CGPath
    let color: RGBColor
    let opacity: CGFloat
}

/// Cuts a border style's pattern into a shape's edge. It cuts only inward, so a layer never grows
/// past its frame, and by at most `maximumDepth` of the edge's size, so a picture always keeps a
/// clean band of border around it.
nonisolated enum BorderEdge {
    /// How deep a pattern cuts at most, as a share of the edge's size.
    static let maximumDepth: CGFloat = 0.6
    /// A picture's longer side as its edge is built: large enough that the path operations'
    /// tolerances fall far below a rubber stamp's smallest speck.
    static let referenceSide: CGFloat = 1000
    /// The most teeth around a loop, so a hairline border spreads them out rather than drawing
    /// thousands too small to see.
    static let maximumPeriods: CGFloat = 400
    /// The most points along an irregular edge, for the same reason.
    static let maximumSamples: CGFloat = 4000

    /// `picture`'s frame with its border's style cut in, or an instant photo's card, or nil when
    /// its border is plain or has no width, which draw as they always have, or it's a transparent
    /// picture's outline, which `edge(for:contour:seed:)` cuts.
    static func edge(for picture: ImageLayer, seed: UUID) -> StyledEdge? {
        let style = picture.drawnBorderStyle
        guard style != .plain, picture.borderWidth > 0, picture.image.fileFormat == .jpeg || style == .instant else {
            return nil
        }
        let image = picture.image
        let key = "\(style.rawValue)-\(seed.uuidString)-\(image.pixelWidth)x\(image.pixelHeight)-\(picture.borderWidth)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let size = LayerGeometry.pictureSize(of: image, scale: 1, slideWidth: referenceSide / LayerGeometry.pictureSide)
        let bounds = CGRect(origin: .zero, size: LayerGeometry.frameSize(of: picture, pictureSize: size))
        let edge = edge(
            around: bounds,
            keeping: LayerGeometry.pictureRect(of: picture, inFrame: bounds),
            style: style,
            size: LayerGeometry.borderWidth(of: picture, pictureSize: size),
            seed: seed
        )
        cache.setObject(edge, forKey: key)
        return edge
    }

    /// A transparent picture's outline, traced as `contour`, with its border's style cut in and its
    /// core kept whole, or nil when its border is plain, an instant photo's card, or has no width.
    static func edge(for picture: ImageLayer, contour: StickerContour, seed: UUID) -> StyledEdge? {
        let style = picture.drawnBorderStyle
        guard let cut = style.cut, picture.borderWidth > 0 else {
            return nil
        }
        let image = picture.image
        let key = "sticker-\(style.rawValue)-\(seed.uuidString)-\(image.id.uuidString)-\(picture.borderWidth)-\(contour.borderWidth)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let size = LayerGeometry.pictureSize(of: image, scale: 1, slideWidth: referenceSide / LayerGeometry.pictureSide)
        let bounds = CGRect(origin: .zero, size: LayerGeometry.frameSize(of: picture, pictureSize: size))
        func placed(_ loop: [CGPoint]) -> [CGPoint] {
            loop.map { CGPoint(x: $0.x * bounds.width, y: $0.y * bounds.height) }
        }
        let edgeSize = LayerGeometry.borderWidth(of: picture, pictureSize: size)
        var generator = SeededGenerator(seed: seed)
        // A loop of one run each, so regular teeth fit it a whole number of times.
        let loops = contour.outline.map { loop in
            EdgeLoop(runs: [EdgeRun(points: placed(loop) + placed(Array(loop.prefix(1))), isCut: true)])
        }
        let points = loops.map { cutPoints($0, cut: cut, size: edgeSize, generator: &generator) }
        // The core's loops run as the outline's do, so the nonzero rule fills the two as one.
        var fill = path(through: points.map { $0.map(\.point) } + contour.core.map(placed))
        if style == .rubberStamp {
            fill = fill.subtracting(specks(in: bounds, keeping: nil, size: edgeSize, generator: &generator))
        }
        let char = style == .burnt ? charBands(along: points, lengths: loops.map(\.length), size: edgeSize, generator: &generator) : []
        let edge = StyledEdge(fill: fill, char: char, bounds: bounds)
        cache.setObject(edge, forKey: key)
        return edge
    }

    /// `text`'s highlight, a box of `size` at the reference size, with its style cut in, or nil
    /// when it's plain, which draws rounded as it always has.
    static func edge(forHighlightOf text: TextLayer, size: CGSize, seed: UUID) -> StyledEdge? {
        let style = text.highlightStyle.drawn(on: .highlight)
        guard text.isHighlighted, style != .plain, size.width > 0, size.height > 0 else {
            return nil
        }
        let key = "highlight-\(style.rawValue)-\(seed.uuidString)-\(size.width)x\(size.height)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let edgeSize = TextLayerLayout.highlightEdge * TextLayerLayout.make(for: text).fontSize
        let edge = edge(around: CGRect(origin: .zero, size: size), keeping: nil, style: style, size: edgeSize, seed: seed)
        cache.setObject(edge, forKey: key)
        return edge
    }

    /// `rect` with `style`'s pattern cut into its edge, `size` the edge's size and its randomness
    /// from `seed`. A rubber stamp's specks leave `kept` alone, where a picture covers them.
    static func edge(around rect: CGRect, keeping kept: CGRect?, style: BorderStyle, size: CGFloat, seed: UUID) -> StyledEdge {
        guard let cut = style.cut, size > 0 else {
            return StyledEdge(fill: CGPath(rect: rect, transform: nil), char: [], bounds: rect)
        }
        var generator = SeededGenerator(seed: seed)
        let loop = EdgeLoop(rect: rect, cornerRadius: cut.cornerRadius * size)
        let points = [cutPoints(loop, cut: cut, size: size, generator: &generator)]
        var fill = path(through: points.map { $0.map(\.point) })
        if style == .rubberStamp {
            fill = fill.subtracting(specks(in: rect, keeping: kept, size: size, generator: &generator))
        }
        let char = style == .burnt ? charBands(along: points, lengths: [loop.length], size: size, generator: &generator) : []
        return StyledEdge(fill: fill, char: char, bounds: rect)
    }

    /// Edges already built, by everything they're built from. `NSCache` is safe to use from any
    /// thread, so the screen and an export share it.
    private static let cache: NSCache<NSString, StyledEdge> = {
        let cache = NSCache<NSString, StyledEdge>()
        cache.countLimit = 200
        return cache
    }()
}

// MARK: - Styles

/// How a style cuts its edge.
nonisolated private enum Cut: Sendable {
    case regular(Tooth)
    case irregular(Roughness)

    /// How round the corners a pattern's runs leave between them are, as a share of the edge's
    /// size.
    var cornerRadius: CGFloat {
        switch self {
        case .regular(let tooth): tooth.cornerRadius
        case .irregular(let roughness): roughness.cornerRadius
        }
    }
}

/// A tooth repeated a whole number of times along each run of an edge, so teeth land alike on a
/// rectangle's corners. Lengths are shares of the edge's size.
nonisolated private struct Tooth: Sendable {
    let period: CGFloat
    /// Where through a tooth, from 0 to 1, points are cut: its corners and enough of its curves.
    let phases: [CGFloat]
    /// A tooth whose sides meet a corner in a point too sharp to read as part of it rounds the
    /// corner instead, starting and ending each side on its top.
    var cornerRadius: CGFloat = 0
    /// How deep the edge is cut at a phase.
    let depth: @Sendable (CGFloat) -> CGFloat
}

/// A band of a burnt edge's char: how far in from the edge it reaches at most, as a share of the
/// edge's size, and its color.
nonisolated private struct CharShade: Sendable {
    let reach: CGFloat
    let color: RGBColor
    let opacity: CGFloat
}

nonisolated private extension BorderStyle {
    var cut: Cut? {
        switch self {
        case .jagged: .regular(.jagged)
        case .wavy: .regular(.wave)
        case .scalloped: .regular(.scallop)
        case .postageStamp: .regular(.perforation)
        case .torn: .irregular(.torn)
        case .burnt: .irregular(.burnt)
        case .rubberStamp: .irregular(.inked)
        default: nil
        }
    }
}

nonisolated private extension Tooth {
    /// Pinking shears' teeth: half the edge deep at right angles, their tips on the corners.
    static let jagged = Tooth(period: 1, phases: [0, 0.5]) { phase in
        0.5 * (1 - abs(1 - 2 * phase))
    }

    /// A gentle wave a third of the edge deep, its crests meeting at rounded corners.
    static let wave = Tooth(period: 1.6, phases: (0..<16).map { CGFloat($0) / 16 }, cornerRadius: 0.5) { phase in
        0.35 * (1 - cos(2 * .pi * phase)) / 2
    }

    /// Round bumps meeting in points, their tops meeting at corners rounded as they are:
    /// semicircles as deep as most of a narrow border, so they still read as round there.
    static let scallop: Tooth = {
        let radius: CGFloat = 0.45
        let period = 2 * radius
        // Even steps around the bump's circle, from its top.
        let phases = (0..<16).map { step in
            let along = sin(-.pi / 2 + CGFloat(step) * .pi / 16) / 2
            return along < 0 ? along + 1 : along
        }
        return Tooth(period: period, phases: phases.sorted(), cornerRadius: radius) { phase in
            let offset = (phase < 0.5 ? phase : phase - 1) * period
            return radius - (max(0, radius * radius - offset * offset)).squareRoot()
        }
    }()

    /// A stamp's perforations: holes punched on the cut, with bridges two-thirds as wide between
    /// them, as a sheet's are, and whole bridges on the corners.
    static let perforation: Tooth = {
        let radius: CGFloat = 0.3
        let period: CGFloat = 1
        // Even steps around the hole's half that's cut out.
        let hole = (0...12).map { step in
            0.5 + radius * cos(.pi - CGFloat(step) * .pi / 12) / period
        }
        return Tooth(period: period, phases: [0] + hole) { phase in
            let offset = (phase - 0.5) * period
            return abs(offset) < radius ? (radius * radius - offset * offset).squareRoot() : 0
        }
    }()
}

nonisolated private extension Roughness {
    /// Paper torn by hand: wandering, with sharp little tears along it.
    static let torn = Roughness(depth: 0.55, feature: 1.2, octaves: 5, isSmooth: false, contrast: 2.2, cornerRadius: 1)
    /// Paper burnt away: broad, smooth bites, which the char darkens, round the corners further
    /// than its char reaches in.
    static let burnt = Roughness(depth: 0.45, feature: 2, octaves: 4, isSmooth: true, contrast: 1.8, cornerRadius: 1.3)
    /// A rubber stamp's inked edge: barely rough.
    static let inked = Roughness(depth: 0.12, feature: 0.5, octaves: 2, isSmooth: false, contrast: 1.5, cornerRadius: 0.25)
    /// How ragged the char's bands run, each over most of its reach.
    static let char = Roughness(depth: 1, feature: 1.2, octaves: 3, isSmooth: true, contrast: 1.6)
}

nonisolated private extension CharShade {
    /// Scorched brown over most of the border, darkening to near black where the edge burnt away,
    /// as burnt paper does. Each band overlaps those nearer the edge, so they build up there.
    static let bands = [
        CharShade(reach: 0.7, color: RGBColor(red: 0.55, green: 0.36, blue: 0.15), opacity: 0.35),
        CharShade(reach: 0.45, color: RGBColor(red: 0.38, green: 0.21, blue: 0.08), opacity: 0.5),
        CharShade(reach: 0.26, color: RGBColor(red: 0.2, green: 0.1, blue: 0.04), opacity: 0.65),
        CharShade(reach: 0.12, color: RGBColor(red: 0.06, green: 0.03, blue: 0.02), opacity: 0.85)
    ]
}

// MARK: - Cutting

nonisolated extension BorderEdge {
    /// `loop`'s points with `cut` cut in.
    fileprivate static func cutPoints(_ loop: EdgeLoop, cut: Cut, size: CGFloat, generator: inout SeededGenerator) -> [EdgePoint] {
        switch cut {
        case .regular(let tooth):
            cutTeeth(loop, tooth: tooth, size: size)
        case .irregular(let roughness):
            cutNoise(loop, roughness: roughness, size: size, generator: &generator)
        }
    }

    /// Each loop of `points` as a closed subpath, filled by the nonzero rule.
    fileprivate static func path(through loops: [[CGPoint]]) -> CGPath {
        let path = CGMutablePath()
        for points in loops {
            path.addLines(between: points)
            path.closeSubpath()
        }
        return path
    }

    /// `loop`'s points with `tooth` cut into its cut runs a whole number of times each.
    private static func cutTeeth(_ loop: EdgeLoop, tooth: Tooth, size: CGFloat) -> [EdgePoint] {
        let period = max(tooth.period * size, loop.length / maximumPeriods)
        var points: [EdgePoint] = []
        for run in loop.runs {
            guard run.isCut else {
                points += run.points(at: Array(run.distances.dropLast())) { _ in 0 }
                continue
            }
            let count = max(1, (run.length / period).rounded())
            let length = run.length / count
            let phases = (0..<Int(count)).flatMap { index in
                tooth.phases.map { (CGFloat(index), $0) }
            }
            points += run.points(at: phases.map { ($0.0 + $0.1) * length }) { index in
                tooth.depth(phases[index].1) * size
            }
        }
        return points
    }

    /// `loop`'s points with noise cut in, evenly spaced along each run at a third of its finest
    /// feature.
    private static func cutNoise(_ loop: EdgeLoop, roughness: Roughness, size: CGFloat, generator: inout SeededGenerator) -> [EdgePoint] {
        let noise = EdgeNoise(roughness, length: loop.length, size: size, generator: &generator)
        let finest = roughness.feature * size / pow(2, CGFloat(roughness.octaves - 1))
        let spacing = max(finest / 3, loop.length / maximumSamples)
        var points: [EdgePoint] = []
        var start: CGFloat = 0
        for run in loop.runs {
            let count = max(1, (run.length / spacing).rounded(.up))
            let distances = (0..<Int(count)).map { CGFloat($0) * run.length / count }
            points += run.points(at: distances) { index in
                roughness.depth * size * noise.value(at: (start + distances[index]) / loop.length)
            }
            start += run.length
        }
        return points
    }

    /// A burnt edge's char along each loop of `loops`, `lengths` long: a band per shade, between
    /// the cut edge and a ragged line in from it, darker toward the edge.
    fileprivate static func charBands(along loops: [[EdgePoint]], lengths: [CGFloat], size: CGFloat, generator: inout SeededGenerator) -> [CharBand] {
        CharShade.bands.map { shade in
            let inner = zip(loops, lengths).map { points, length in
                // Points along an irregular cut are evenly spaced, so their order places them.
                let noise = EdgeNoise(.char, length: length, size: size, generator: &generator)
                return points.enumerated().map { index, point in
                    point.inset(by: shade.reach * size * (0.4 + 0.6 * noise.value(at: CGFloat(index) / CGFloat(points.count))))
                }
            }
            let band = CGMutablePath()
            band.addPath(path(through: loops.map { $0.map(\.point) }))
            band.addPath(path(through: inner.map { $0.reversed() }))
            return CharBand(path: band, color: shade.color, opacity: shade.opacity)
        }
    }

    /// A rubber stamp's specks where its ink didn't take, scattered over `rect` but not deep within
    /// `kept`, which a picture covers: about a third of a grid's cells take one, the cells a third
    /// of the edge's size apart, or further where there'd be more than `maximumSpecks`, as along a
    /// hairline border.
    fileprivate static func specks(in rect: CGRect, keeping kept: CGRect?, size: CGFloat, generator: inout SeededGenerator) -> CGPath {
        let chance: CGFloat = 0.35
        let hidden = kept.map { $0.width * $0.height } ?? 0
        let spacing = max(0.3 * size, ((rect.width * rect.height - hidden) * chance / maximumSpecks).squareRoot())
        let path = CGMutablePath()
        for strip in strips(of: rect, around: kept?.insetBy(dx: spacing, dy: spacing)) {
            for row in 0..<Int((strip.height / spacing).rounded(.up)) {
                for column in 0..<Int((strip.width / spacing).rounded(.up)) {
                    let isSpecked = generator.nextUnit() < chance
                    let center = CGPoint(
                        x: strip.minX + (CGFloat(column) + generator.nextUnit()) * spacing,
                        y: strip.minY + (CGFloat(row) + generator.nextUnit()) * spacing
                    )
                    let radius = (0.04 + 0.08 * generator.nextUnit()) * size
                    // Not past the strip, where its rows, rounded up, run on toward the picture.
                    if isSpecked, strip.contains(center) {
                        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
                    }
                }
            }
        }
        return path
    }

    /// The most specks a rubber stamp takes, which subtracting from its edge stays quick enough
    /// for a slider to drag.
    private static let maximumSpecks: CGFloat = 600

    /// `rect` less `hole`, as the strips above and below it and beside it, or `rect` whole.
    private static func strips(of rect: CGRect, around hole: CGRect?) -> [CGRect] {
        guard let hole = hole?.intersection(rect), !hole.isEmpty else {
            return [rect]
        }
        return [
            CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: hole.minY - rect.minY),
            CGRect(x: rect.minX, y: hole.maxY, width: rect.width, height: rect.maxY - hole.maxY),
            CGRect(x: rect.minX, y: hole.minY, width: hole.minX - rect.minX, height: hole.height),
            CGRect(x: hole.maxX, y: hole.minY, width: rect.maxX - hole.maxX, height: hole.height)
        ]
    }
}
