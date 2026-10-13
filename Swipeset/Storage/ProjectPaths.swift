//
//  ProjectPaths.swift
//  Swipeset
//

import Foundation

/// Where projects and their files live on disk.
nonisolated struct ProjectPaths: Sendable {
    /// Holds a folder for each project, with its JSON and image copies, and the trash that
    /// deleted projects pass through.
    let root: URL
    /// Holds imports and exports in flight, which never outlive a launch.
    let temporary: URL

    static let live = ProjectPaths(root: .applicationSupportDirectory, temporary: .temporaryDirectory)

    var projects: URL {
        root.appending(path: "Projects", directoryHint: .isDirectory)
    }

    var trash: URL {
        root.appending(path: "Trash", directoryHint: .isDirectory)
    }

    var imports: URL {
        temporary.appending(path: "Imports", directoryHint: .isDirectory)
    }

    var exports: URL {
        temporary.appending(path: "Exports", directoryHint: .isDirectory)
    }

    func folder(for projectID: UUID) -> URL {
        projects.appending(path: projectID.uuidString, directoryHint: .isDirectory)
    }

    func file(for projectID: UUID) -> URL {
        folder(for: projectID).appending(path: "project.json", directoryHint: .notDirectory)
    }

    func imagesFolder(for projectID: UUID) -> URL {
        folder(for: projectID).appending(path: "Images", directoryHint: .isDirectory)
    }

    /// The copy named `fileName`, a `PlacedImage.fileName`, in project `projectID`.
    func imageFile(named fileName: String, in projectID: UUID) -> URL {
        imagesFolder(for: projectID).appending(path: fileName, directoryHint: .notDirectory)
    }
}
