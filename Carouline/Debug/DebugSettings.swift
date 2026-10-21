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
        case customRatio
        case layout
        case export
        case layers
        case addLayer
        case editLayer

        /// Whether it opens in the open project, rather than on the projects list.
        var opensInProject: Bool {
            switch self {
            case .newProject, .customRatio: false
            case .layout, .export, .layers, .addLayer, .editLayer: true
            }
        }
    }

    /// Projects to swap in for the real ones, in a store of their own, leaving the real ones alone.
    enum Store {
        /// `SampleProjects.all`, with something left to fill in each, and no tour.
        case samples
        /// `DemoProjects.all`, finished for screenshots, and no tour.
        case demo
        /// An empty store, which adds the sample a fresh install's first launch does, and
        /// TipKit's datastore for one, so the tour starts over.
        case firstLaunch
    }

    /// Nil for the real projects.
    let store: Store?
    /// Leaves one sample photo's copy and the sample sticker's unwritten, so they show as missing.
    let missesSampleImage: Bool
    /// The project, by its place in the list, to open on launch.
    let openProjectIndex: Int?
    /// A photo in the open project to select on launch, by slide and cell index.
    let selectedCell: (slide: Int, cell: Int)?
    /// A layer in the open project to select on launch, by slide and layer index from the bottom.
    let selectedLayer: (slide: Int, layer: Int)?
    /// A photo in the open project to hold on launch, to place by tapping a cell.
    let heldPhoto: Hold?
    let sheet: Sheet?

    /// A photo to hold on launch.
    enum Hold: Equatable {
        /// A cell's, by slide and cell index.
        case cell(slide: Int, cell: Int)
        /// The tray's, by its place in the tray.
        case tray(Int)
    }

    /// Reads `-DebugSampleProjects` (`YES` swaps in sample projects, without the tour),
    /// `-DebugDemoProjects` (`YES` swaps in demo projects for screenshots, without the tour, unless
    /// `-DebugSampleProjects` is on), `-DebugMissingImages` (`YES` leaves a sample photo's copy and
    /// the sample sticker's out, so they show as missing, with `-DebugSampleProjects`),
    /// `-DebugFirstLaunch` (`YES` swaps in an empty store that adds the first-launch sample, and an
    /// empty tips datastore that starts the tour, as a fresh install does, unless either of the
    /// others is on), `-DebugOpenProject` (a project's index in the list, from 0),
    /// `-DebugSelectCell` (a photo to frame in it, as slide and cell indexes like `2,0`),
    /// `-DebugSelectLayer` (a layer to move in it, as slide and layer indexes like `2,0`, layers
    /// counted from the bottom), `-DebugHoldPhoto` (a photo in it to hold for placing, as slide and
    /// cell indexes like `2,0`, or as `tray,` and its place in the tray from 0, like `tray,1`) and
    /// `-DebugSheet` (`newProject`, or `customRatio` for its custom page, on the list, or `layout`,
    /// `export`, `layers`, `addLayer` or `editLayer` in the open project, the last three for
    /// `-DebugSelectLayer`'s slide or else the first, and `editLayer` for its layer) from
    /// `arguments`, ignoring values it can't parse.
    init(arguments: [String: Any] = [:]) {
        func isOn(_ key: String) -> Bool {
            (arguments[key] as? String).map(Self.isTrue) ?? false
        }
        store = if isOn("DebugSampleProjects") {
            .samples
        } else if isOn("DebugDemoProjects") {
            .demo
        } else if isOn("DebugFirstLaunch") {
            .firstLaunch
        } else {
            nil
        }
        missesSampleImage = isOn("DebugMissingImages")
        openProjectIndex = (arguments["DebugOpenProject"] as? String).flatMap { Int($0) }
        let cell = (arguments["DebugSelectCell"] as? String)?.split(separator: ",").compactMap { Int($0) } ?? []
        selectedCell = cell.count == 2 ? (cell[0], cell[1]) : nil
        let layer = (arguments["DebugSelectLayer"] as? String)?.split(separator: ",").compactMap { Int($0) } ?? []
        selectedLayer = layer.count == 2 ? (layer[0], layer[1]) : nil
        heldPhoto = (arguments["DebugHoldPhoto"] as? String).flatMap(Self.hold(from:))
        sheet = (arguments["DebugSheet"] as? String).flatMap(Sheet.init(rawValue:))
    }

    /// Settings from this process's launch arguments. Only the argument domain is read, so
    /// nothing a previous session wrote to `UserDefaults` can switch an override on.
    static func fromLaunchArguments() -> DebugSettings {
        DebugSettings(arguments: UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain))
    }

    /// `2,0` as slide 2's cell 0, or `tray,1` as the tray's second photo.
    private nonisolated static func hold(from string: String) -> Hold? {
        let parts = string.split(separator: ",")
        guard parts.count == 2, let index = Int(parts[1]) else {
            return nil
        }
        if parts[0] == "tray" {
            return .tray(index)
        }
        return Int(parts[0]).map { .cell(slide: $0, cell: index) }
    }

    private nonisolated static func isTrue(_ string: String) -> Bool {
        ["yes", "true", "1"].contains(string.lowercased())
    }
}
#endif
