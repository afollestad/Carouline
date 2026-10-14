//
//  CountingStore.swift
//  CaroulineTests
//

import Foundation
@testable import Carouline

/// A store that counts its loads and saves and keeps nothing.
actor CountingStore: ProjectStoring {
    nonisolated let paths = ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)
    nonisolated let storedProjectCount = 0
    private(set) var loads = 0
    private(set) var saves = 0

    func loadAll() async -> StoredProjects {
        loads += 1
        // Gives a second caller the chance to start its own load while this one is out.
        await Task.yield()
        return StoredProjects()
    }

    func save(_ project: Project) {
        saves += 1
    }

    func delete(projectID: UUID) {}

    func delete(_ unreadable: UnreadableProject) {}

    func adoptImage(at source: URL, as fileName: String, in projectID: UUID) -> Bool {
        true
    }

    func deleteImages(_ fileNames: [String], in projectID: UUID) {}
}
