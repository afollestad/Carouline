//
//  ShareTipPlacementTests.swift
//  CaroulineTests
//

import SwiftUI
import Testing
@testable import Carouline

struct ShareTipPlacementTests {
    private let screen = CGSize(width: 860, height: 580)

    /// A bar across the top, as on an iPhone held upright, puts the button above the screen. Its
    /// middle sits 22pt from the tip's edge, which TipKit's own corners keep the arrow from reaching.
    @Test func pointsUpAtAButtonInABarAcrossTheTop() {
        let placement = ShareTipPlacement(button: CGRect(x: 346, y: -50, width: 36, height: 36), in: CGSize(width: 402, height: 750))
        #expect(placement.arrowEdge == .top)
        #expect(placement.alignment == .topTrailing)
        #expect(placement.padding == EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        #expect(placement.cornerRadius == 22 - ShareTipPlacement.arrowCornerMargin)
    }

    /// An iPad's bar sets the button nearer the screen's edge, so the tip follows its glass there
    /// and its arrow reaches the button's middle as on a phone.
    @Test func linesUpWithTheButtonsGlass() {
        let placement = ShareTipPlacement(button: CGRect(x: 694, y: -40, width: 36, height: 36), in: CGSize(width: 744, height: 1000))
        #expect(placement.padding.trailing == 10)
        #expect(placement.cornerRadius == 22 - ShareTipPlacement.arrowCornerMargin)
    }

    /// A button with a title is wide enough for the arrow to reach its middle past TipKit's corners.
    @Test func keepsTipKitsCornersForAWideButton() {
        let placement = ShareTipPlacement(button: CGRect(x: 600, y: -40, width: 90, height: 36), in: CGSize(width: 744, height: 1000))
        #expect(placement.cornerRadius == nil)
    }

    @Test func neverSquaresItsCornersPastTheMinimum() {
        let placement = ShareTipPlacement(button: CGRect(x: 380, y: -40, width: 16, height: 16), in: CGSize(width: 402, height: 750))
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
