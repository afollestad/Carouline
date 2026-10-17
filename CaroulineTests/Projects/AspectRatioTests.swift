//
//  AspectRatioTests.swift
//  CaroulineTests
//

import CoreGraphics
import Testing
@testable import Carouline

struct AspectRatioTests {
    @Test(arguments: AspectRatio.allCases)
    func exportsAtItsRatio(_ ratio: AspectRatio) throws {
        let sides = ratio.rawValue.split(separator: ":").compactMap { Double($0) }
        try #require(sides.count == 2)

        #expect(ratio.exportSize.width == 1080)
        #expect(abs(ratio.exportSize.height - 1080 * sides[1] / sides[0]) < 1)
    }
}
