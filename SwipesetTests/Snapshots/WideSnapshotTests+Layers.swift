//
//  WideSnapshotTests+Layers.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension WideSnapshotTests {
    @Test func layeredSlides() async {
        await assertScreenSnapshot(of: projectScreen(layeredProject), on: .wide)
    }
}
