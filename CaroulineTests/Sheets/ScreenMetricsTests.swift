//
//  ScreenMetricsTests.swift
//  CaroulineTests
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Carouline

struct ScreenMetricsTests {
    private static let phone = CGSize(width: 402, height: 874)

    @Test func confirmsAtAPhonesDialogWidth() {
        #expect(ScreenMetrics(size: Self.phone).confirmationWidth(at: .large) == 240)
    }

    /// As the system's dialog does, nearly to the screen's sides, for text too large for its width.
    @Test func widensToThePhoneAtAccessibilitySizes() {
        #expect(ScreenMetrics(size: Self.phone).confirmationWidth(at: .accessibility3) == 366)
    }

    /// Held sideways, a phone keeps its upright width rather than spanning the whole screen.
    @Test func widensOnlyToAPhonesShorterSide() {
        let sideways = CGSize(width: Self.phone.height, height: Self.phone.width)
        #expect(ScreenMetrics(size: sideways).confirmationWidth(at: .accessibility3) == 366)
    }

    @Test func confirmsAtAWideScreensDialogWidthAtEverySize() {
        let wide = ScreenMetrics(size: CGSize(width: 744, height: 1133), isRegularWidth: true)
        #expect(wide.confirmationWidth(at: .large) == 288)
        #expect(wide.confirmationWidth(at: .accessibility3) == 288)
    }

    /// Before the window has measured itself, it keeps the phone's width rather than collapsing.
    @Test func keepsThePhonesWidthUntilMeasured() {
        #expect(ScreenMetrics().confirmationWidth(at: .accessibility3) == 240)
    }
}
