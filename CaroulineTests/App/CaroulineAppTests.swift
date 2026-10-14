//
//  CaroulineAppTests.swift
//  CaroulineTests
//

import Testing
@testable import Carouline

struct CaroulineAppTests {
    /// If this ever fails, the app running under the tests loads and sweeps the real projects mid-run.
    @Test func knowsWhenItsHostingTests() {
        #expect(CaroulineApp.isHostingTests)
    }
}
