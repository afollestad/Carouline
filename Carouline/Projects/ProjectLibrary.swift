//
//  ProjectLibrary.swift
//  Carouline
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
    /// Cells with a photo on its way in.
    var importingCells: Set<CellAddress> = []
    /// Slides with pictures on their way in as layers, and how many each.
    var importingLayers: [UUID: Int] = [:]
    /// Projects with photos on their way into the tray, and how many each.
    var importingTray: [UUID: Int] = [:]
    /// The last write or import that failed, until someone shows it.
    var failure: LibraryFailure?

    @ObservationIgnored let store: any ProjectStoring
    /// How many projects the store held when the library was made, and the sample a first launch
    /// adds, for placeholders to stand in for until it loads.
    @ObservationIgnored let expectedCount: Int
    /// Builds the sample a fresh install's first load adds, which only the app passes, so
    /// previews and tests keep the projects they set up.
    @ObservationIgnored private let makeSample: (@Sendable () -> Project)?
    /// The newest write. Each one waits for the last, so a slow save can't land after, and
    /// overwrite, a newer one, and a file is only deleted once the JSON that dropped it is saved.
    @ObservationIgnored private var lastWrite: Task<Void, Never>?
    @ObservationIgnored private var loading: Task<Void, Never>?
    /// The latest import into each cell. An earlier one still running finds itself replaced
    /// and discards its photo, so the last photo picked wins however long each takes.
    @ObservationIgnored var importTokens: [CellAddress: UUID] = [:]

    /// `projects`, when given, stand in for the store's, with `unreadable`, as previews and
    /// snapshots need. Otherwise the first load adds the project `makeSample` builds to a store
    /// that's awaiting one.
    init(
        store: any ProjectStoring,
        projects: [Project]? = nil,
        unreadable: [UnreadableProject] = [],
        makeSample: (@Sendable () -> Project)? = nil
    ) {
        self.store = store
        self.projects = projects ?? []
        self.unreadable = unreadable
        isLoaded = projects != nil
        self.makeSample = makeSample
        // From the parameters, since `isLoaded` can't be read until every property is set.
        if projects == nil {
            let count = store.storedProjectCount
            expectedCount = count == 0 && makeSample != nil && store.isAwaitingSample ? 1 : count
        } else {
            expectedCount = 0
        }
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
        let makeSample = makeSample
        let loading = Task {
            var stored = await store.loadAll()
            // A sample that fails leaves the empty state, and the next launch tries again.
            if let makeSample, let sample = try? await store.addSample(makeSample) {
                stored.projects.insert(sample, at: 0)
            }
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
    func update(_ id: UUID, deletingImages: [PlacedImage] = [], _ change: (inout Project) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            return
        }
        var project = projects[index]
        change(&project)
        project.modifiedAt = .now
        projects.remove(at: index)
        projects.insert(project, at: 0)
        let fileNames = deletingImages.map(\.fileName)
        write { store in
            try await store.save(project)
            if !fileNames.isEmpty {
                await store.deleteImages(fileNames, in: id)
            }
        }
    }

    /// Waits for every write made so far.
    func flush() async {
        await lastWrite?.value
    }

    func write(_ operation: @escaping @Sendable (any ProjectStoring) async throws -> Void) {
        let previous = lastWrite
        let store = store
        lastWrite = Task {
            await previous?.value
            do {
                try await operation(store)
            } catch {
                failure = LibraryFailure(kind: .write, error: error)
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

/// A change that didn't take.
struct LibraryFailure: Identifiable {
    enum Kind {
        /// A change that didn't reach the disk.
        case write
        /// A photo that couldn't be read or copied in.
        case importPhoto
        /// A missing photo that couldn't come back from the library.
        case restorePhoto
    }

    let id = UUID()
    let kind: Kind
    let error: any Error

    var title: String {
        switch kind {
        case .write: "Couldn't Save Changes"
        case .importPhoto: "Couldn't Add Photo"
        case .restorePhoto: "Couldn't Restore Photo"
        }
    }

    var message: String {
        switch kind {
        case .write: "Carouline couldn't save your latest changes. \(error.localizedDescription)"
        case .importPhoto: "Carouline couldn't read that photo. Try another, or the same one again."
        case .restorePhoto:
            switch error as? RestoreError {
            case .denied: "Carouline can't see your photo library. Allow access in Settings to restore this photo."
            case .originalGone: "The original is no longer in your photo library. Choose another photo, or remove this one."
            case nil: "Carouline couldn't read the original from your photo library. Try again later."
            }
        }
    }
}

/// A cell in a slide of a project.
nonisolated struct CellAddress: Codable, Hashable, Identifiable, Sendable {
    let projectID: UUID
    let slideID: UUID
    let index: Int

    var id: Self { self }
}
