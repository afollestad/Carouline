//
//  CustomPresetsTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

@MainActor
struct CustomPresetsTests {
    private let temporary = TemporaryDirectory("CustomPresetsTests")

    private var file: URL {
        temporary.url.appending(path: "CustomPresets.json", directoryHint: .notDirectory)
    }

    private func shape() throws -> AspectRatio {
        try #require(AspectRatio(width: 5, height: 7, pixelWidth: 2000, pixelHeight: 2800))
    }

    @Test func keepsWhatItSavesAndDeletes() throws {
        let presets = CustomPresets(file: file)
        presets.save(try shape(), name: "Etsy")
        presets.save(.portrait, name: "Mine")
        #expect(CustomPresets(file: file).presets == presets.presets)

        let etsy = try #require(presets.presets.first)
        presets.delete(etsy.id)

        #expect(CustomPresets(file: file).presets.map(\.name) == ["Mine"])
    }

    /// A shape saved again under the same name, or a preset's shape with no name, which the sheet
    /// has a tile for, adds nothing.
    @Test func savesEachShapeAndNameOnce() throws {
        let presets = CustomPresets(file: file)
        presets.save(try shape(), name: "Etsy")
        presets.save(try shape(), name: " Etsy ")
        presets.save(.portrait, name: "")
        #expect(presets.presets.map(\.name) == ["Etsy"])

        presets.save(try shape(), name: "Shop")
        #expect(presets.presets.map(\.name) == ["Etsy", "Shop"])
    }

    @Test func trimsANameAndCaptionsOneWithoutBySize() throws {
        let presets = CustomPresets(file: file)
        presets.save(try shape(), name: "  Etsy\n")
        presets.save(try shape(), name: "   ")

        #expect(presets.presets.map(\.name) == ["Etsy", ""])
        #expect(presets.presets.map(\.caption) == ["Etsy", "2000 × 2800"])
        #expect(presets.presets.map(\.spokenLabel) == ["5 by 7 Portrait, Etsy", "5 by 7 Portrait, 2000 by 2800 pixels"])
    }

    /// A newer build's file stays as it was, since saving over it would drop what this build
    /// can't read.
    @Test func neverSavesOverANewerFile() throws {
        let newer = #"{"formatVersion": \#(CustomPresetsFile.currentFormatVersion + 1), "presets": []}"#
        try FileManager.default.createDirectory(at: temporary.url, withIntermediateDirectories: true)
        try Data(newer.utf8).write(to: file)

        let presets = CustomPresets(file: file)
        presets.save(try shape(), name: "Etsy")

        #expect(!presets.canSave)
        #expect(presets.presets.isEmpty)
        #expect(try String(contentsOf: file, encoding: .utf8) == newer)
    }
}
