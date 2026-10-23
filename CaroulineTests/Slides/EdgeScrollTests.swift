//
//  EdgeScrollTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

/// How fast a layer held at the strip's edge scrolls it, on a strip as wide as iPhone 18 Pro's.
struct EdgeScrollTests {
    private let width: CGFloat = 402

    @Test func holdsStillAwayFromTheEdges() {
        #expect(EdgeScroll.velocity(at: 201, across: width) == 0)
        #expect(EdgeScroll.velocity(at: EdgeScroll.zone, across: width) == 0)
    }

    /// Faster the nearer the edge, toward it.
    @Test func scrollsTowardTheEdgeItsHeldAt() {
        #expect(EdgeScroll.velocity(at: 0, across: width) == -EdgeScroll.maximumSpeed)
        #expect(EdgeScroll.velocity(at: EdgeScroll.zone / 2, across: width) == -EdgeScroll.maximumSpeed / 2)
        #expect(EdgeScroll.velocity(at: width, across: width) == EdgeScroll.maximumSpeed)
    }

    /// A strip too narrow for both edges' room has no middle to hold still in, so it never scrolls.
    @Test func holdsStillOnANarrowStrip() {
        #expect(EdgeScroll.velocity(at: 0, across: 80) == 0)
    }
}
