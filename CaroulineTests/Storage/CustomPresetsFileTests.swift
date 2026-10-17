//
//  CustomPresetsFileTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

struct CustomPresetsFileTests {
    private let temporary = TemporaryDirectory("CustomPresetsFileTests")

    /// In a folder that doesn't exist yet, as a store's root before its first project.
    private var file: URL {
        temporary.url.appending(path: "Support/CustomPresets.json", directoryHint: .notDirectory)
    }

    @Test func readsWhatItWrites() throws {
        let shape = try #require(AspectRatio(width: 5, height: 7, pixelWidth: 2000, pixelHeight: 2800))
        let presets = [CustomPreset(name: "Etsy", aspectRatio: shape), CustomPreset(name: "", aspectRatio: .square)]

        try CustomPresetsFile.write(presets, to: file)

        #expect(CustomPresetsFile.read(file) == .presets(presets))
    }

    @Test func readsNoneWithoutAFileOrFromOneThatDoesntParse() throws {
        #expect(CustomPresetsFile.read(file) == .presets([]))
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file)
        #expect(CustomPresetsFile.read(file) == .presets([]))
    }

    /// One damaged preset, or one past the shapes a build makes, doesn't lose the rest.
    @Test func skipsAPresetItCantRead() throws {
        try CustomPresetsFile.write([CustomPreset(name: "Kept", aspectRatio: .portrait)], to: file)
        let json = try String(contentsOf: file, encoding: .utf8)
        let damaged = json.replacingOccurrences(
            of: "\"presets\" : [",
            with: #""presets" : [{"id": "6A1F2B3C-0000-4000-8000-000000000001", "name": "Wide", "aspectRatio": "3:1"},"#
        )
        try Data(damaged.utf8).write(to: file)

        guard case .presets(let presets) = CustomPresetsFile.read(file) else {
            Issue.record("Expected presets")
            return
        }
        #expect(presets.map(\.name) == ["Kept"])
    }

    @Test func refusesANewerVersion() throws {
        try CustomPresetsFile.write([], to: file)
        let json = try String(contentsOf: file, encoding: .utf8)
        let newer = json.replacingOccurrences(
            of: "\"formatVersion\" : \(CustomPresetsFile.currentFormatVersion)",
            with: "\"formatVersion\" : \(CustomPresetsFile.currentFormatVersion + 1)"
        )
        try Data(newer.utf8).write(to: file)

        #expect(CustomPresetsFile.read(file) == .newerVersion)
    }
}
