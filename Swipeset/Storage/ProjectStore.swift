//
//  ProjectStore.swift
//  Swipeset
//

import Foundation

/// Reads and writes projects and their image copies.
nonisolated protocol ProjectStoring: Sendable {
    var paths: ProjectPaths { get }

    /// Every project on disk, after sweeping away files nothing refers to. Call it once, before
    /// anything can change a project, since it deletes images no saved project refers to yet.
    func loadAll() async -> StoredProjects
    func save(_ project: Project) async throws
    func delete(projectID: UUID) async throws
    func delete(_ unreadable: UnreadableProject) async throws
    /// Moves an imported copy at `source` into `projectID`'s folder as `imageID`. Returns false,
    /// having deleted the copy, when the project was deleted while it imported.
    func adoptImage(at source: URL, as imageID: UUID, in projectID: UUID) async throws -> Bool
    func deleteImages(_ imageIDs: [UUID], in projectID: UUID) async
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
/// an `Images` folder of copies named by `PlacedImage.id`.
actor ProjectStore: ProjectStoring {
    nonisolated let paths: ProjectPaths
    /// Projects deleted this launch. A save or import still in flight for one would otherwise
    /// create its folder again, with a project the user already threw away.
    private var deleted: Set<UUID> = []

    init(paths: ProjectPaths = .live) {
        self.paths = paths
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

    func adoptImage(at source: URL, as imageID: UUID, in projectID: UUID) throws -> Bool {
        guard !deleted.contains(projectID) else {
            try? FileManager.default.removeItem(at: source)
            return false
        }
        try FileManager.default.createDirectory(at: paths.imagesFolder(for: projectID), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: source, to: paths.imageFile(imageID, in: projectID))
        return true
    }

    func deleteImages(_ imageIDs: [UUID], in projectID: UUID) {
        for imageID in imageIDs {
            try? FileManager.default.removeItem(at: paths.imageFile(imageID, in: projectID))
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

    /// Deletes copies left by a replace, removal or import that a crash cut short.
    private func removeUnreferencedImages(of project: Project) {
        let kept = Set(project.images.map(\.fileName))
        let folder = paths.imagesFolder(for: project.id)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        for name in names where !kept.contains(name) {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }

    private func directories(in folder: URL) -> [URL] {
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
    private var projects: [UUID: Project]

    init(projects: [Project] = [], paths: ProjectPaths = ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)) {
        self.projects = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        self.paths = paths
    }

    func loadAll() -> StoredProjects {
        StoredProjects(projects: projects.values.sorted { $0.modifiedAt > $1.modifiedAt })
    }

    func save(_ project: Project) {
        projects[project.id] = project
    }

    func delete(projectID: UUID) {
        projects[projectID] = nil
    }

    func delete(_ unreadable: UnreadableProject) {}

    func adoptImage(at source: URL, as imageID: UUID, in projectID: UUID) -> Bool {
        projects[projectID] != nil
    }

    func deleteImages(_ imageIDs: [UUID], in projectID: UUID) {}
}
