//
//  BorderEdgeTests.swift
//  CaroulineTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Carouline

/// Border styles' edges, read from their paths.
struct BorderEdgeTests {
    private let rect = CGRect(x: 0, y: 0, width: 1120, height: 870)
    private let size: CGFloat = 60
    private let seed = UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))

    /// The styles that cut their edge in.
    private let cutStyles: [BorderStyle] = [.jagged, .wavy, .scalloped, .torn, .burnt, .postageStamp, .rubberStamp]

    private func edge(_ style: BorderStyle, rect: CGRect? = nil, size: CGFloat? = nil, seed: UUID? = nil) -> StyledEdge {
        BorderEdge.edge(
            around: rect ?? self.rect,
            keeping: (rect ?? self.rect).insetBy(dx: size ?? self.size, dy: size ?? self.size),
            style: style,
            size: size ?? self.size,
            seed: seed ?? self.seed
        )
    }

    /// Points every `step` around `rect`'s edge.
    private func perimeter(of rect: CGRect, step: CGFloat = 5) -> [CGPoint] {
        let across = stride(from: rect.minX, through: rect.maxX, by: step)
        let down = stride(from: rect.minY, through: rect.maxY, by: step)
        return across.flatMap { [CGPoint(x: $0, y: rect.minY), CGPoint(x: $0, y: rect.maxY)] }
            + down.flatMap { [CGPoint(x: rect.minX, y: $0), CGPoint(x: rect.maxX, y: $0)] }
    }

    /// An edge only cuts in, so the layer never grows past its frame, and along its sides never
    /// deeper than `maximumDepth`, nor at its rounded corners into the picture, so a band of border
    /// always rings it.
    @Test(arguments: [BorderStyle.jagged, .wavy, .scalloped, .torn, .burnt, .postageStamp])
    func cutsInNoDeeperThanItsMost(style: BorderStyle) {
        let fill = edge(style).fill
        let band = rect.insetBy(dx: BorderEdge.maximumDepth * size, dy: BorderEdge.maximumDepth * size)
        let sides = perimeter(of: band).filter { point in
            min(abs(point.x - band.minX), abs(point.x - band.maxX)) > 1.5 * size
                || min(abs(point.y - band.minY), abs(point.y - band.maxY)) > 1.5 * size
        }

        #expect(rect.insetBy(dx: -0.01, dy: -0.01).contains(fill.boundingBox))
        #expect(sides.allSatisfy { fill.contains($0) })
        #expect(perimeter(of: rect.insetBy(dx: size, dy: size)).allSatisfy { fill.contains($0) })
    }

    /// Each style takes something off its edge somewhere, past where a plain one's runs.
    @Test(arguments: [BorderStyle.jagged, .wavy, .scalloped, .torn, .burnt, .postageStamp, .rubberStamp])
    func cutsItsEdge(style: BorderStyle) {
        let fill = edge(style).fill
        let near = rect.insetBy(dx: 0.1 * size, dy: 0.1 * size)

        #expect(perimeter(of: near).contains { !fill.contains($0) })
    }

    /// A rubber stamp's specks fall in its border, never under the picture it frames.
    @Test func specksOnlyTheBorder() {
        let fill = edge(.rubberStamp).fill
        let band = rect.insetBy(dx: 0.5 * size, dy: 0.5 * size)
        let picture = rect.insetBy(dx: size, dy: size)

        #expect(perimeter(of: band, step: 2).contains { !fill.contains($0) })
        #expect(perimeter(of: picture.insetBy(dx: 0.5 * size, dy: 0.5 * size)).allSatisfy { fill.contains($0) })
    }

    /// Every side takes a whole number of teeth, starting and ending alike at its corners, so each
    /// side's teeth mirror about its middle.
    @Test(arguments: [BorderStyle.jagged, .wavy, .scalloped, .postageStamp])
    func fitsWholeTeethToEachSide(style: BorderStyle) {
        let fill = edge(style).fill
        let depth = 0.2 * size
        let across = stride(from: rect.minX + 2, through: rect.midX, by: 3).map { CGPoint(x: $0, y: rect.minY + depth) }
        let down = stride(from: rect.minY + 2, through: rect.midY, by: 3).map { CGPoint(x: rect.minX + depth, y: $0) }

        let mirroredAcross = across.filter { fill.contains($0) != fill.contains(CGPoint(x: rect.maxX - ($0.x - rect.minX), y: $0.y)) }
        let mirroredDown = down.filter { fill.contains($0) != fill.contains(CGPoint(x: $0.x, y: rect.maxY - ($0.y - rect.minY))) }
        // Points on a cut can fall either way.
        #expect(mirroredAcross.count <= 2, "\(style.name)")
        #expect(mirroredDown.count <= 2, "\(style.name)")
    }

    /// Pinking shears' tips and a stamp's bridges stand on the corners; a wave's crests and a
    /// scallop's bumps meet in rounded ones, rather than points.
    @Test func cornersItsTeethToSuit() {
        let corners = [
            CGPoint(x: rect.minX + 1, y: rect.minY + 1),
            CGPoint(x: rect.maxX - 1, y: rect.minY + 1),
            CGPoint(x: rect.maxX - 1, y: rect.maxY - 1),
            CGPoint(x: rect.minX + 1, y: rect.maxY - 1)
        ]
        let postage = edge(.postageStamp).fill

        #expect(corners.allSatisfy { postage.contains($0) })
        for style in [BorderStyle.wavy, .scalloped] {
            let fill = edge(style).fill
            #expect(corners.allSatisfy { !fill.contains($0) }, "\(style.name)")
        }
    }

    /// An edge is built from shares of its size, so it cuts the same at twice the size.
    @Test(arguments: [BorderStyle.jagged, .torn, .postageStamp])
    func cutsAlikeAtAnySize(style: BorderStyle) {
        let small = edge(style).fill
        let large = edge(style, rect: rect.applying(CGAffineTransform(scaleX: 2, y: 2)), size: 2 * size).fill

        let points = perimeter(of: rect.insetBy(dx: 0.25 * size, dy: 0.25 * size), step: 7)
        let mismatched = points.filter { point in
            small.contains(point) != large.contains(CGPoint(x: 2 * point.x, y: 2 * point.y))
        }
        // Points on a cut can fall either way after scaling's rounding.
        #expect(mismatched.count <= points.count / 50)
    }

    /// A layer's randomness is its own and stays put from one draw to the next.
    @Test func followsItsSeed() {
        let other = UUID(uuid: (16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1))

        #expect(edge(.torn).fill == edge(.torn).fill)
        #expect(edge(.torn).fill != edge(.torn, seed: other).fill)
        #expect(edge(.rubberStamp).fill == edge(.rubberStamp).fill)
    }

    /// Only a burnt edge chars, in bands that build darker toward the edge.
    @Test func charsOnlyABurntEdge() {
        let char = edge(.burnt).char

        #expect(!char.isEmpty)
        #expect(cutStyles.filter { $0 != .burnt }.allSatisfy { edge($0).char.isEmpty })
        let darkness = char.map { 1 - ($0.color.red + $0.color.green + $0.color.blue) / 3 }
        #expect(darkness == darkness.sorted())
    }

    /// A plain border, or one with no width, draws as it always has; an instant photo's frame is
    /// a plain card.
    @Test func leavesAPlainBorderAlone() throws {
        let image = PlacedImage(assetIdentifier: nil, pixelWidth: 400, pixelHeight: 300)

        #expect(BorderEdge.edge(for: ImageLayer(image: image, borderWidth: 0.04), seed: seed) == nil)
        #expect(BorderEdge.edge(for: ImageLayer(image: image, borderStyle: .wavy), seed: seed) == nil)
        let instant = try #require(BorderEdge.edge(for: ImageLayer(image: image, borderWidth: 0.04, borderStyle: .instant), seed: seed))
        #expect(instant.fill == CGPath(rect: instant.bounds, transform: nil))
    }
}
