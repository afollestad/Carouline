//
//  ShareTipPlacementTests.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

struct ShareTipPlacementTests {
    private let screen = CGSize(width: 860, height: 580)

    /// A bar across the top, as on an iPhone held upright, puts the button above the screen.
    @Test func pointsUpAtAButtonInABarAcrossTheTop() {
        let placement = ShareTipPlacement(button: CGRect(x: 800, y: -50, width: 38, height: 38), in: screen)
        #expect(placement.arrowEdge == .top)
        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding == EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    /// iPhone Duo's bar runs down the trailing edge, beside the screen, so the tip reaches the
    /// screen's edge and its arrow sits level with the button.
    @Test func pointsAcrossAtAButtonBesideTheTrailingEdge() {
        let placement = ShareTipPlacement(button: CGRect(x: 880, y: 100, width: 38, height: 38), in: screen)
        #expect(placement.arrowEdge == .trailing)
        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding == EdgeInsets(top: 119 - ShareTipPlacement.arrowCornerInset, leading: 16, bottom: 0, trailing: 0))
    }

    @Test func keepsClearOfAButtonInsideTheScreen() {
        let placement = ShareTipPlacement(button: CGRect(x: 800, y: 100, width: 38, height: 38), in: screen)
        #expect(placement.arrowEdge == .trailing)
        #expect(placement.padding.trailing == 60 + ShareTipPlacement.buttonGap)
    }

    @Test func pointsAcrossAtAButtonBesideTheLeadingEdge() {
        let placement = ShareTipPlacement(button: CGRect(x: 20, y: 100, width: 38, height: 38), in: screen)
        #expect(placement.arrowEdge == .leading)
        #expect(placement.alignment == .topLeading)
        #expect(placement.padding.top == 119 - ShareTipPlacement.arrowCornerInset)
        #expect(placement.padding.leading == 58 + ShareTipPlacement.buttonGap)
        #expect(placement.padding.trailing == 16)
    }

    @Test func neverRisesAboveTheScreen() {
        let placement = ShareTipPlacement(button: CGRect(x: 880, y: 0, width: 38, height: 38), in: screen)
        #expect(placement.padding.top == 0)
    }
}
