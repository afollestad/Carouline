//
//  SwipesetAppTests.swift
//  SwipesetTests
//

import Testing
@testable import Swipeset

struct SwipesetAppTests {
    /// If this ever fails, the app running under the tests loads and sweeps the real projects mid-run.
    @Test func knowsWhenItsHostingTests() {
        #expect(SwipesetApp.isHostingTests)
    }
}
