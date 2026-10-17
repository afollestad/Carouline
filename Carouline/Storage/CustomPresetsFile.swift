//
//  CustomPresetsFile.swift
//  Carouline
//

import Foundation

/// The shapes saved from the New Project sheet, as JSON wrapped with the version of its shape.
nonisolated enum CustomPresetsFile {
    /// Bump with `ProjectFile.currentFormatVersion` whenever `AspectRatio`'s shape changes, since
    /// an older build would drop every preset it can't read the next time it saved.
    static let currentFormatVersion = 1

    enum Contents: Hashable, Sendable {
        /// The presets in the file, in the order saved, leaving out any that don't read, or none
        /// when there's no file, or one that doesn't parse, which the next save replaces.
        case presets([CustomPreset])
        /// Saved by a newer build, which this one never saves over.
        case newerVersion
    }

    static func read(_ url: URL) -> Contents {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: url),
              let probe = try? decoder.decode(Probe.self, from: data) else {
            return .presets([])
        }
        guard probe.formatVersion <= currentFormatVersion else {
            return .newerVersion
        }
        guard let document = try? decoder.decode(ReadDocument.self, from: data) else {
            return .presets([])
        }
        return .presets(document.presets.compactMap(\.preset))
    }

    /// Creates `url`'s folder first, which a store only makes as it saves its first project.
    static func write(_ presets: [CustomPreset], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(SavedDocument(formatVersion: currentFormatVersion, presets: presets))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private struct Probe: Decodable {
        let formatVersion: Int
    }

    private struct SavedDocument: Encodable {
        let formatVersion: Int
        let presets: [CustomPreset]
    }

    private struct ReadDocument: Decodable {
        let presets: [Entry]
    }

    /// A preset, or nil when it doesn't read, so one damaged preset doesn't lose the rest.
    private struct Entry: Decodable {
        let preset: CustomPreset?

        init(from decoder: any Decoder) throws {
            preset = try? decoder.singleValueContainer().decode(CustomPreset.self)
        }
    }
}
