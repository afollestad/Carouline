//
//  ProjectLibrary.swift
//  Swipeset
//

import Foundation
import Observation

/// Every project, as the screens show and change them. Changes apply at once in memory and
/// reach the disk through `store` in the order they were made.
@Observable
final class ProjectLibrary {
    /// Most recently changed first.
    private(set) var projects: [Project]
    private(set) var unreadable: [UnreadableProject] = []
    private(set) var isLoaded: Bool
    /// The last write that failed, until someone shows it.
    var writeFailure: WriteFailure?

    @ObservationIgnored let store: any ProjectStoring
    /// The newest write. Each one waits for the last, so a slow save can't land after, and
    /// overwrite, a newer one, and a file is only deleted once the JSON that dropped it is saved.
    @ObservationIgnored private var lastWrite: Task<Void, Never>?
    @ObservationIgnored private var loading: Task<Void, Never>?

    /// `projects`, when given, stand in for the store's, with `unreadable`, as previews and
    /// snapshots need.
    init(store: any ProjectStoring, projects: [Project]? = nil, unreadable: [UnreadableProject] = []) {
        self.store = store
        self.projects = projects ?? []
        self.unreadable = unreadable
        isLoaded = projects != nil
    }

    /// Loads the store's projects once, however many windows ask. A second load would sweep
    /// again, and could delete a photo a window imported since the first.
    func load() async {
        guard !isLoaded else {
            return
        }
        if let loading {
            await loading.value
            return
        }
        let store = store
        let loading = Task {
            let stored = await store.loadAll()
            projects = stored.projects
            unreadable = stored.unreadable
            isLoaded = true
        }
        self.loading = loading
        await loading.value
    }

    func project(_ id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func createProject(aspectRatio: AspectRatio) -> Project {
        let project = Project(name: nextName(), aspectRatio: aspectRatio)
        projects.insert(project, at: 0)
        write { try await $0.save(project) }
        return project
    }

    /// Renames to `name` trimmed, or leaves the name alone when that's empty.
    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != project(id)?.name else {
            return
        }
        update(id) { $0.name = trimmed }
    }

    func delete(_ id: UUID) {
        projects.removeAll { $0.id == id }
        write { try await $0.delete(projectID: id) }
    }

    func delete(_ unreadable: UnreadableProject) {
        self.unreadable.removeAll { $0 == unreadable }
        write { try await $0.delete(unreadable) }
    }

    /// Changes project `id` and saves it, then deletes `deletingImages`, the copies the change
    /// stopped referring to.
    func update(_ id: UUID, deletingImages: [UUID] = [], _ change: (inout Project) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            return
        }
        var project = projects[index]
        change(&project)
        project.modifiedAt = .now
        projects.remove(at: index)
        projects.insert(project, at: 0)
        write { store in
            try await store.save(project)
            if !deletingImages.isEmpty {
                await store.deleteImages(deletingImages, in: id)
            }
        }
    }

    /// Waits for every write made so far.
    func flush() async {
        await lastWrite?.value
    }

    private func write(_ operation: @escaping @Sendable (any ProjectStoring) async throws -> Void) {
        let previous = lastWrite
        let store = store
        lastWrite = Task {
            await previous?.value
            do {
                try await operation(store)
            } catch {
                writeFailure = WriteFailure(error: error)
            }
        }
    }

    /// "Untitled", then "Untitled 2" and up, skipping names in use.
    private func nextName() -> String {
        let names = Set(projects.map(\.name))
        guard names.contains("Untitled") else {
            return "Untitled"
        }
        var number = 2
        while names.contains("Untitled \(number)") {
            number += 1
        }
        return "Untitled \(number)"
    }
}

/// A write that didn't reach the disk.
struct WriteFailure: Identifiable {
    let id = UUID()
    let error: any Error
}
