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
    }

    /// Swaps the real projects for `SampleProjects` in a store of their own.
    let usesSampleProjects: Bool
    let sheet: Sheet?

    /// Reads `-DebugSampleProjects` (`YES` swaps in sample projects, leaving the real ones alone)
    /// and `-DebugSheet` (`newProject` opens the new project sheet) from `arguments`, ignoring
    /// values it can't parse.
    init(arguments: [String: Any] = [:]) {
        usesSampleProjects = (arguments["DebugSampleProjects"] as? String).map(Self.isTrue) ?? false
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
