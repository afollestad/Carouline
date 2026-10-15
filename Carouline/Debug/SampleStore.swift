//
//  SampleStore.swift
//  Carouline
//

#if DEBUG
import Foundation

/// Stores of `SampleProjects` or `DemoProjects` under `tmp`, so they never mix with real projects.
enum SampleStore {
    static let paths = ProjectPaths(
        root: .temporaryDirectory.appending(path: "DebugSamples", directoryHint: .isDirectory),
        temporary: .temporaryDirectory.appending(path: "DebugSamplesTemporary", directoryHint: .isDirectory)
    )
    static let firstLaunchPaths = ProjectPaths(
        root: .temporaryDirectory.appending(path: "DebugFirstLaunch", directoryHint: .isDirectory),
        temporary: .temporaryDirectory.appending(path: "DebugFirstLaunchTemporary", directoryHint: .isDirectory)
    )
    /// TipKit's datastore for a first launch, reset with its store, so the sample's tour starts
    /// over too, leaving the real datastore alone.
    static let firstLaunchTips = firstLaunchPaths.root.appending(path: "Tips", directoryHint: .isDirectory)

    /// A store refilled with fresh `projects`, so every launch starts from the same ones. It
    /// writes them before the store exists, and so before any window can load or change them.
    /// `missingImage` leaves the copies of `SampleProjects.missingImageIDs` out.
    static func make(_ projects: [Project], missingImage: Bool = false) -> ProjectStore {
        try? FileManager.default.removeItem(at: paths.root)
        for project in projects {
            try? FileManager.default.createDirectory(at: paths.imagesFolder(for: project.id), withIntermediateDirectories: true)
            try? ProjectFile.encode(project).write(to: paths.file(for: project.id), options: .atomic)
            for image in project.images where !(missingImage && SampleProjects.missingImageIDs.contains(image.id)) {
                if let drawn = SampleImages.image(for: image) {
                    try? ImageImporter.write(drawn, to: paths.imageFile(named: image.fileName, in: project.id), format: image.fileFormat)
                }
            }
        }
        return ProjectStore(paths: paths)
    }

    /// An empty store, emptied again each launch, so every launch is a fresh install's first and
    /// adds `SampleProjects.firstLaunch`, with an empty folder for `firstLaunchTips`.
    static func makeFirstLaunch() -> ProjectStore {
        try? FileManager.default.removeItem(at: firstLaunchPaths.root)
        try? FileManager.default.createDirectory(at: firstLaunchTips, withIntermediateDirectories: true)
        return ProjectStore(paths: firstLaunchPaths)
    }
}
#endif
