//
//  DebugSettings.swift
//  Swipeset
//

#if DEBUG
import Foundation
import Observation

/// Overrides for reaching states in the simulator without a tap. Launch arguments seed them,
/// and nothing is persisted, so an override can't outlive the session that set it.
@Observable
final class DebugSettings {
    /// A sheet to open on launch, since `simctl` can't tap to one.
    enum Sheet: String {
        case newProject
        case layout
        case export
    }

    /// Swaps the real projects for `SampleProjects` in a store of their own.
    let usesSampleProjects: Bool
    /// Leaves one sample photo's copy and the sample sticker's unwritten, so they show as missing.
    let missesSampleImage: Bool
    /// The project, by its place in the list, to open on launch.
    let openProjectIndex: Int?
    /// A photo in the open project to select on launch, by slide and cell index.
    let selectedCell: (slide: Int, cell: Int)?
    let sheet: Sheet?

    /// Reads `-DebugSampleProjects` (`YES` swaps in sample projects, leaving the real ones alone),
    /// `-DebugMissingImages` (`YES` leaves a sample photo's copy and the sample sticker's out, so
    /// they show as missing),
    /// `-DebugOpenProject` (a project's index in the list, from 0), `-DebugSelectCell` (a photo
    /// to frame in it, as slide and cell indexes like `2,0`) and `-DebugSheet` (`newProject` on
    /// the list, or `layout` or `export` in the open project) from `arguments`, ignoring
    /// values it can't parse.
    init(arguments: [String: Any] = [:]) {
        usesSampleProjects = (arguments["DebugSampleProjects"] as? String).map(Self.isTrue) ?? false
        missesSampleImage = (arguments["DebugMissingImages"] as? String).map(Self.isTrue) ?? false
        openProjectIndex = (arguments["DebugOpenProject"] as? String).flatMap { Int($0) }
        let cell = (arguments["DebugSelectCell"] as? String)?.split(separator: ",").compactMap { Int($0) } ?? []
        selectedCell = cell.count == 2 ? (cell[0], cell[1]) : nil
        sheet = (arguments["DebugSheet"] as? String).flatMap(Sheet.init(rawValue:))
    }

    /// Settings from this process's launch arguments. Only the argument domain is read, so
    /// nothing a previous session wrote to `UserDefaults` can switch an override on.
    static func fromLaunchArguments() -> DebugSettings {
        DebugSettings(arguments: UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain))
    }

    private nonisolated static func isTrue(_ string: String) -> Bool {
        ["yes", "true", "1"].contains(string.lowercased())
    }
}
#endif
