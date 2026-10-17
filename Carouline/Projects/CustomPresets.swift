//
//  CustomPresets.swift
//  Carouline
//

import Foundation
import Observation

/// A shape saved from the New Project sheet's custom page, which the sheet offers from then on.
nonisolated struct CustomPreset: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    /// What the user called it, or empty for no name.
    let name: String
    let aspectRatio: AspectRatio

    init(id: UUID = UUID(), name: String, aspectRatio: AspectRatio) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aspectRatio = aspectRatio
    }

    /// Its name, or else its size, which its tile shows under its ratio.
    var caption: String {
        name.isEmpty ? "\(pixels(aspectRatio.pixelWidth)) × \(pixels(aspectRatio.pixelHeight))" : name
    }

    /// Its tile as VoiceOver should read it, as in "5 by 7 Portrait, Etsy".
    var spokenLabel: String {
        let detail = name.isEmpty ? "\(aspectRatio.pixelWidth) by \(aspectRatio.pixelHeight) pixels" : name
        return "\(aspectRatio.spokenRatio) \(aspectRatio.name), \(detail)"
    }

    /// Without grouping, as the custom page's fields write a size.
    private func pixels(_ side: Int) -> String {
        side.formatted(.number.grouping(.never))
    }
}

/// The shapes saved from the New Project sheet's custom page, in the order saved.
@Observable
final class CustomPresets {
    private(set) var presets: [CustomPreset]
    /// False when the file is from a newer build, which this one never saves over, since it would
    /// drop what this build can't read.
    private(set) var canSave: Bool
    @ObservationIgnored private let file: URL?

    /// Reads `file` at once: a few hundred bytes, which the first New Project sheet needs.
    init(file: URL) {
        self.file = file
        switch CustomPresetsFile.read(file) {
        case .presets(let presets):
            self.presets = presets
            canSave = true
        case .newerVersion:
            presets = []
            canSave = false
        }
    }

    /// `presets` kept in memory alone, as previews and snapshots need.
    init(presets: [CustomPreset]) {
        self.presets = presets
        canSave = true
        file = nil
    }

    /// Adds `ratio`, called `name`, after the others, unless the same shape is saved already
    /// under the same name, or it's a preset's shape with no name, whose tile the sheet has.
    func save(_ ratio: AspectRatio, name: String) {
        let preset = CustomPreset(name: name, aspectRatio: ratio)
        let isSaved = presets.contains { $0.aspectRatio == ratio && $0.name == preset.name }
        guard canSave, !isSaved, !(preset.name.isEmpty && AspectRatio.presets.contains(ratio)) else {
            return
        }
        presets.append(preset)
        write()
    }

    func delete(_ id: UUID) {
        guard canSave else {
            return
        }
        presets.removeAll { $0.id == id }
        write()
    }

    /// At once, so each change lands in the order made, which a few hundred bytes allows. A write
    /// that fails keeps the change for this launch alone, which a convenience can live with.
    private func write() {
        guard let file else {
            return
        }
        try? CustomPresetsFile.write(presets, to: file)
    }
}
