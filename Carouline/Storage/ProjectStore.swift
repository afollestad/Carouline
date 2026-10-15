//
//  ProjectStore.swift
//  Carouline
//

import Foundation

/// Reads and writes projects and their image copies.
nonisolated protocol ProjectStoring: Sendable {
    var paths: ProjectPaths { get }
    /// How many projects `loadAll()` will find, readable or not, counted from their folders
    /// without reading or sweeping any, so it's cheap enough to ask before the first frame. A
    /// folder a crash left without its JSON counts, though `loadAll()` sweeps it away.
    var storedProjectCount: Int { get }
    /// Whether the store holds no projects and has never had its first-launch sample, as on a
    /// fresh install's first launch, so `addSample(_:)` would add one. Cheap enough to ask
    /// before the first frame.
    var isAwaitingSample: Bool { get }

    /// Every project on disk, after sweeping away files nothing refers to. Call it once, before
    /// anything can change a project, since it deletes images no saved project refers to yet.
    func loadAll() async -> StoredProjects
    /// Adds the project `make` builds, with its `SampleImages` drawn as its copies, and returns
    /// it, when `isAwaitingSample`. Whenever it adds one or finds projects, it marks the store,
    /// so a deleted sample stays gone and an update doesn't add one beside the projects already
    /// there. Call it after `loadAll()`, whose sweep clears folders a crash left without their
    /// JSON, which would otherwise count as projects.
    func addSample(_ make: @Sendable () -> Project) async throws -> Project?
    func save(_ project: Project) async throws
    func delete(projectID: UUID) async throws
    func delete(_ unreadable: UnreadableProject) async throws
    /// Moves an imported copy at `source` into `projectID`'s folder as `fileName`, its
    /// `PlacedImage.fileName`. Returns false, having deleted the copy, when the project was
    /// deleted while it imported.
    func adoptImage(at source: URL, as fileName: String, in projectID: UUID) async throws -> Bool
    /// Deletes the copies named `fileNames`, each a `PlacedImage.fileName`.
    func deleteImages(_ fileNames: [String], in projectID: UUID) async
}

/// What a launch finds on disk, newest first.
nonisolated struct StoredProjects: Sendable {
    var projects: [Project] = []
    var unreadable: [UnreadableProject] = []
}

/// A project folder this build can't read, kept until the user deletes it.
nonisolated struct UnreadableProject: Identifiable, Hashable, Sendable {
    let folder: URL
    let reason: ProjectFile.ReadError

    var id: URL { folder }
}

/// Keeps each project in its own folder under `ProjectPaths.projects`, as `project.json` beside
/// an `Images` folder of copies named by `PlacedImage.fileName`.
actor ProjectStore: ProjectStoring {
    nonisolated let paths: ProjectPaths
    /// Projects deleted this launch. A save or import still in flight for one would otherwise
    /// create its folder again, with a project the user already threw away.
    private var deleted: Set<UUID> = []

    init(paths: ProjectPaths = .live) {
        self.paths = paths
    }

    nonisolated var storedProjectCount: Int {
        directories(in: paths.projects).count
    }

    nonisolated var isAwaitingSample: Bool {
        storedProjectCount == 0 && !hasSampleMarker
    }

    func loadAll() -> StoredProjects {
        for folder in [paths.trash, paths.imports, paths.exports] {
            try? FileManager.default.removeItem(at: folder)
        }
        var stored = StoredProjects()
        for folder in directories(in: paths.projects) {
            let file = folder.appending(path: "project.json", directoryHint: .notDirectory)
            guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
                // Saving creates the folder with its JSON, so one without is left from a crash.
                try? discard(folder)
                continue
            }
            do {
                let project = try ProjectFile.decode(Data(contentsOf: file))
                guard folder.lastPathComponent == project.id.uuidString else {
                    throw ProjectFile.ReadError.damaged
                }
                removeUnreferencedImages(of: project)
                stored.projects.append(project)
            } catch {
                stored.unreadable.append(UnreadableProject(folder: folder, reason: error as? ProjectFile.ReadError ?? .damaged))
            }
        }
        stored.projects.sort { $0.modifiedAt > $1.modifiedAt }
        return stored
    }

    func addSample(_ make: @Sendable () -> Project) throws -> Project? {
        guard isAwaitingSample else {
            if !hasSampleMarker {
                markSampleAdded()
            }
            return nil
        }
        let sample = make()
        do {
            try FileManager.default.createDirectory(at: paths.imagesFolder(for: sample.id), withIntermediateDirectories: true)
            for image in sample.images {
                guard let drawn = SampleImages.image(for: image) else {
                    throw ImageImporter.ImportError.unwritable
                }
                try ImageImporter.write(drawn, to: paths.imageFile(named: image.fileName, in: sample.id), format: image.fileFormat)
            }
            try save(sample)
        } catch {
            // Otherwise the folder would stand in as a project, with a placeholder, until the next
            // launch swept it.
            try? discard(paths.folder(for: sample.id))
            throw error
        }
        // A sample saved without its marker still shows. The next launch finds it and marks then.
        markSampleAdded()
        return sample
    }

    func save(_ project: Project) throws {
        guard !deleted.contains(project.id) else {
            return
        }
        try FileManager.default.createDirectory(at: paths.folder(for: project.id), withIntermediateDirectories: true)
        try ProjectFile.encode(project).write(to: paths.file(for: project.id), options: .atomic)
    }

    func delete(projectID: UUID) throws {
        deleted.insert(projectID)
        try discard(paths.folder(for: projectID))
    }

    func delete(_ unreadable: UnreadableProject) throws {
        guard unreadable.folder.deletingLastPathComponent().standardizedFileURL == paths.projects.standardizedFileURL else {
            return
        }
        if let id = UUID(uuidString: unreadable.folder.lastPathComponent) {
            deleted.insert(id)
        }
        try discard(unreadable.folder)
    }

    func adoptImage(at source: URL, as fileName: String, in projectID: UUID) throws -> Bool {
        guard !deleted.contains(projectID) else {
            try? FileManager.default.removeItem(at: source)
            return false
        }
        try FileManager.default.createDirectory(at: paths.imagesFolder(for: projectID), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: source, to: paths.imageFile(named: fileName, in: projectID))
        return true
    }

    func deleteImages(_ fileNames: [String], in projectID: UUID) {
        for fileName in fileNames {
            try? FileManager.default.removeItem(at: paths.imageFile(named: fileName, in: projectID))
        }
    }

    /// Moves `folder` into the trash, which a rename does at once, then empties the trash. A crash
    /// partway through deleting the folder in place could leave its JSON with only some of its
    /// photos; this way the next launch's sweep finishes the job.
    private func discard(_ folder: URL) throws {
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.createDirectory(at: paths.trash, withIntermediateDirectories: true)
        let destination = paths.trash.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.moveItem(at: folder, to: destination)
        try? FileManager.default.removeItem(at: destination)
    }

    private nonisolated var hasSampleMarker: Bool {
        FileManager.default.fileExists(atPath: paths.sampleMarker.path(percentEncoded: false))
    }

    private func markSampleAdded() {
        try? FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try? Data().write(to: paths.sampleMarker)
    }

    /// Deletes copies left by a replace, removal or import that a crash cut short.
    private func removeUnreferencedImages(of project: Project) {
        let kept = Set(project.images.map(\.fileName))
        let folder = paths.imagesFolder(for: project.id)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        for name in names where !kept.contains(name) {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    private nonisolated func directories(in folder: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }
}

/// Holds projects in memory, for previews and screens that never touch the disk.
actor MockProjectStore: ProjectStoring {
    nonisolated let paths: ProjectPaths
    /// The projects it started with, without its saves since, which is all a library asks for
    /// before it loads.
    nonisolated let storedProjectCount: Int
    /// Never, so previews and snapshots show only the projects they were given.
    nonisolated let isAwaitingSample = false
    private var projects: [UUID: Project]

    init(projects: [Project] = [], paths: ProjectPaths = ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)) {
        self.projects = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        self.paths = paths
        storedProjectCount = projects.count
    }

    func loadAll() -> StoredProjects {
        StoredProjects(projects: projects.values.sorted { $0.modifiedAt > $1.modifiedAt })
    }

    func addSample(_ make: @Sendable () -> Project) -> Project? {
        nil
    }

    func save(_ project: Project) {
        projects[project.id] = project
    }

    func delete(projectID: UUID) {
        projects[projectID] = nil
    }

    func delete(_ unreadable: UnreadableProject) {}

    func adoptImage(at source: URL, as fileName: String, in projectID: UUID) -> Bool {
        projects[projectID] != nil
    }

    func deleteImages(_ fileNames: [String], in projectID: UUID) {}
}
