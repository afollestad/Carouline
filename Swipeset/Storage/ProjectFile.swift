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
    /// Version 3 added layers, blur and PNG copies, which a version 2 build would drop when it
    /// saved, and whose PNG copies its launch sweep would delete.
    /// Version 4 moved the style from the project onto each slide, which a version 3 build
    /// can't read.
    static let currentFormatVersion = slideStyleVersion

    /// The first version to keep a style on each slide rather than one on the project.
    private static let slideStyleVersion = 4

    enum ReadError: Error, Hashable, Sendable {
        /// Not a project this build understands: unparseable, unversioned, or with a shape out of
        /// range, as a slide with more cells than its layout or a span its layout can't have.
        /// Out-of-range layer values, blur and styles are clamped instead, since clamping keeps
        /// every photo and layer.
        case damaged
        /// Saved by a newer build. Reading it could drop what this build doesn't know, and saving
        /// over it would lose that for good, so it stays untouched.
        case newerVersion(Int)
    }

    static func encode(_ project: Project) throws -> Data {
        try makeEncoder().encode(Document(formatVersion: currentFormatVersion, project: project))
    }

    /// Versions 1 to 3 kept one style on the project, which each slide takes. Otherwise `Slide`
    /// reads a missing `span` as 1, and missing layers and blur as none, `PlacedImage` a missing
    /// `fileFormat` as JPEG, and `ImageLayer` a missing `hasShadow` as none.
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
        var project = document.project
        if probe.formatVersion < slideStyleVersion {
            // Every build before it required the project's style.
            guard let legacy = try? decoder.decode(LegacyDocument.self, from: data) else {
                throw ReadError.damaged
            }
            for index in project.slides.indices {
                project.slides[index].style = legacy.project.style
            }
        }
        return try validated(project)
    }

    /// Pads a slide missing trailing cells, as an interrupted write of a future layout change
    /// might leave it, but refuses one with more cells than its layout, which would drop photos,
    /// or a span its layout can't have. Clamps layers, blur and styles into range, and drops
    /// text layers with no text, which a build never saves.
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
            project.slides[index].layers = slide.layers.compactMap { layer in
                if case .text(let text) = layer.content, text.isBlank {
                    return nil
                }
                return layer.clamped(span: slide.span)
            }
            project.slides[index].blur = min(max(slide.blur, 0), Slide.maximumBlur)
            project.slides[index].style = slide.style.clamped()
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

    /// A version 1 to 3 file, for the style its project held.
    private struct LegacyDocument: Decodable {
        let project: LegacyProject
    }

    private struct LegacyProject: Decodable {
        let style: SlideStyle
    }
}
