//
//  SampleStore.swift
//  Swipeset
//

#if DEBUG
import Foundation

/// A store of `SampleProjects` under `tmp`, so samples never mix with real projects.
enum SampleStore {
    static let paths = ProjectPaths(
        root: .temporaryDirectory.appending(path: "DebugSamples", directoryHint: .isDirectory),
        temporary: .temporaryDirectory.appending(path: "DebugSamplesTemporary", directoryHint: .isDirectory)
    )

    /// A store refilled with fresh samples, so every launch starts from the same ones. It writes
    /// them before the store exists, and so before any window can load or change them.
    static func make() -> ProjectStore {
        try? FileManager.default.removeItem(at: paths.root)
        for project in SampleProjects.all {
            try? FileManager.default.createDirectory(at: paths.folder(for: project.id), withIntermediateDirectories: true)
            try? ProjectFile.encode(project).write(to: paths.file(for: project.id), options: .atomic)
        }
        return ProjectStore(paths: paths)
    }
}
#endif
