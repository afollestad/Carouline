//
//  DebugSettings.swift
//  Carouline
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
        case layers
        case addLayer
        case editLayer
    }

    /// Swaps the real projects for `SampleProjects` in a store of their own.
    let usesSampleProjects: Bool
    /// Leaves one sample photo's copy and the sample sticker's unwritten, so they show as missing.
    let missesSampleImage: Bool
    /// Swaps the real projects for an empty store of its own, so each launch adds the sample a
    /// fresh install's first launch does, and TipKit's datastore for one, so its tour starts over.
    let simulatesFirstLaunch: Bool
    /// The project, by its place in the list, to open on launch.
    let openProjectIndex: Int?
    /// A photo in the open project to select on launch, by slide and cell index.
    let selectedCell: (slide: Int, cell: Int)?
    /// A layer in the open project to select on launch, by slide and layer index from the bottom.
    let selectedLayer: (slide: Int, layer: Int)?
    let sheet: Sheet?

    /// Reads `-DebugSampleProjects` (`YES` swaps in sample projects, leaving the real ones alone),
    /// `-DebugMissingImages` (`YES` leaves a sample photo's copy and the sample sticker's out, so
    /// they show as missing), `-DebugFirstLaunch` (`YES` swaps in an empty store that adds the
    /// first-launch sample, and an empty tips datastore that starts its tour, as a fresh install
    /// does, unless `-DebugSampleProjects` is on; it ignores `-DebugMissingImages`),
    /// `-DebugOpenProject` (a project's index in the list, from 0), `-DebugSelectCell` (a photo
    /// to frame in it, as slide and cell indexes like `2,0`), `-DebugSelectLayer` (a layer to
    /// move in it, as slide and layer indexes like `2,0`, layers counted from the bottom) and
    /// `-DebugSheet` (`newProject` on the list, or `layout`, `export`, `layers`, `addLayer` or
    /// `editLayer` in the open project, the last three for `-DebugSelectLayer`'s slide or else the
    /// first, and `editLayer` for its layer) from `arguments`, ignoring values it can't parse.
    init(arguments: [String: Any] = [:]) {
        usesSampleProjects = (arguments["DebugSampleProjects"] as? String).map(Self.isTrue) ?? false
        missesSampleImage = (arguments["DebugMissingImages"] as? String).map(Self.isTrue) ?? false
        simulatesFirstLaunch = (arguments["DebugFirstLaunch"] as? String).map(Self.isTrue) ?? false
        openProjectIndex = (arguments["DebugOpenProject"] as? String).flatMap { Int($0) }
        let cell = (arguments["DebugSelectCell"] as? String)?.split(separator: ",").compactMap { Int($0) } ?? []
        selectedCell = cell.count == 2 ? (cell[0], cell[1]) : nil
        let layer = (arguments["DebugSelectLayer"] as? String)?.split(separator: ",").compactMap { Int($0) } ?? []
        selectedLayer = layer.count == 2 ? (layer[0], layer[1]) : nil
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
