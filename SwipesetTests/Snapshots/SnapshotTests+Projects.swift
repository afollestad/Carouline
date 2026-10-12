//
//  SnapshotTests+Projects.swift
//  SwipesetTests
//

import SwiftUI
import Testing
@testable import Swipeset

extension SnapshotTests {
    @Test func emptyProjects() async {
        await assertScreenSnapshot(of: NavigationStack { ProjectsScreen {} })
    }
}
