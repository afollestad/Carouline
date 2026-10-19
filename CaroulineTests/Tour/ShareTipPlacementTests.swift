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
        let placement = ShareTipPlacement(button: CGRect(x: 760, y: -50, width: 38, height: 38), in: screen)
        #expect(placement.arrowEdge == .top)
        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding == EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        #expect(placement.cornerRadius == nil)
    }

    /// An iPhone's Share button sits 22pt from the tip's edge, which TipKit's own corners keep the
    /// arrow from reaching.
    @Test func tightensItsCornersForAButtonNearTheEdge() {
        let placement = ShareTipPlacement(button: CGRect(x: 346, y: -50, width: 36, height: 36), in: CGSize(width: 402, height: 750))
        #expect(placement.cornerRadius == 22 - ShareTipPlacement.arrowCornerMargin)
    }

    @Test func neverSquaresItsCornersPastTheMinimum() {
        let placement = ShareTipPlacement(button: CGRect(x: 694, y: -40, width: 36, height: 36), in: CGSize(width: 744, height: 1000))
        #expect(placement.cornerRadius == ShareTipPlacement.minimumCornerRadius)
    }

    /// iPhone Duo's bar runs down the trailing edge, beside the screen, so the tip reaches the
    /// screen's edge and its arrow sits level with the button.
    @Test func pointsAcrossAtAButtonBesideTheTrailingEdge() {
        let placement = ShareTipPlacement(button: CGRect(x: 880, y: 100, width: 38, height: 38), in: screen)
        #expect(placement.arrowEdge == .trailing)
        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding == EdgeInsets(top: 119 - ShareTipPlacement.arrowCornerInset, leading: 16, bottom: 0, trailing: 0))
        #expect(placement.cornerRadius == nil)
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
