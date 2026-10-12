//
//  WideSnapshotTests+Projects.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension WideSnapshotTests {
    @Test func emptyProjects() async {
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen {} }, on: .wide)
    }
}
