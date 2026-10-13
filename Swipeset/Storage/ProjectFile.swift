//
//  ProjectFile.swift
//  Swipeset
//

import Foundation

/// A project's JSON, wrapped with the version of its shape.
nonisolated enum ProjectFile {
    /// Bump when a field changes meaning or a new one becomes required, and migrate the old
    /// shape in `decode(_:)`. A new optional field needs no bump, since older files decode it as nil.
    /// Version 2 added panoramas, which a version 1 build can't read and mustn't save over.
    static let currentFormatVersion = 2

    enum ReadError: Error, Hashable, Sendable {
        /// Not a project this build understands: unparseable, unversioned, or with values out of range.
        case damaged
        /// Saved by a newer build. Reading it could drop what this build doesn't know, and saving
        /// over it would lose that for good, so it stays untouched.
        case newerVersion(Int)
    }

    static func encode(_ project: Project) throws -> Data {
        try makeEncoder().encode(Document(formatVersion: currentFormatVersion, project: project))
    }

    /// Version 1 needs no migration: `Slide` reads its missing `span` as 1.
    static func decode(_ data: Data) throws -> Project {
        let decoder = makeDecoder()
        guard let probe = try? decoder.decode(Probe.self, from: data), probe.formatVersion >= 1 else {
            throw ReadError.damaged
        }
        guard probe.formatVersion <= currentFormatVersion else {
            throw ReadError.newerVersion(probe.formatVersion)
        }
        guard let document = try? decoder.decode(Document.self, from: data) else {
            throw ReadError.damaged
        }
        return try validated(document.project)
    }

    /// Pads a slide missing trailing cells, as an interrupted write of a future layout change
    /// might leave it, but refuses one with more cells than its layout, which would drop photos,
    /// or a span its layout can't have.
    private static func validated(_ project: Project) throws -> Project {
        var project = project
        for index in project.slides.indices {
            let slide = project.slides[index]
            guard slide.layout == .panorama ? Slide.panoramaSpans.contains(slide.span) : slide.span == 1 else {
                throw ReadError.damaged
            }
            let expected = slide.layout.grid.cells.count
            let count = slide.cells.count
            guard count <= expected else {
                throw ReadError.damaged
            }
            project.slides[index].cells += Array(repeating: Cell(), count: expected - count)
        }
        return project
    }

    /// Sorted and pretty, so a project diffs readably while debugging. Asset identifiers hold
    /// slashes, which stay unescaped.
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private struct Probe: Decodable {
        let formatVersion: Int
    }

    private struct Document: Codable {
        let formatVersion: Int
        let project: Project
    }
}
