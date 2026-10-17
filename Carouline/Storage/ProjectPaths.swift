//
//  ProjectPaths.swift
//  Carouline
//

import Foundation

/// Where projects and their files live on disk.
nonisolated struct ProjectPaths: Sendable {
    /// Holds a folder for each project, with its JSON and image copies, the trash that deleted
    /// projects pass through, the marker that the first-launch sample was added, and the shapes
    /// saved from the New Project sheet.
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

    /// Written once the store has had its first-launch sample, or found projects there already,
    /// so a deleted sample never comes back.
    var sampleMarker: URL {
        root.appending(path: "SampleAdded", directoryHint: .notDirectory)
    }

    /// Beside the projects rather than in the app's defaults, so a debug store's presets stay apart
    /// from the real ones.
    var customPresets: URL {
        root.appending(path: "CustomPresets.json", directoryHint: .notDirectory)
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
