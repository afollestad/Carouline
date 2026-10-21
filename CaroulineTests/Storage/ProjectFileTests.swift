//
//  ProjectFileTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

struct ProjectFileTests {
    @Test func readsVersion1() throws {
        let project = try ProjectFile.decode(Data(Self.version1.utf8))
        #expect(project.name == "Lisbon")
        #expect(project.aspectRatio == .portrait)
        #expect(project.createdAt == Date(timeIntervalSince1970: 1_791_817_200))
        let slide = try #require(project.slides.first)
        #expect(slide.layout == .twoColumns)
        #expect(slide.span == 1)
        #expect(slide.cells.count == 2)
        let image = try #require(slide.cells[0].image)
        #expect(image.assetIdentifier == "ABC123/L0/001")
        #expect(image.crop == ImageCrop(scale: 1.5, centerX: 0.25, centerY: 0.5))
        #expect(image.pixelSize == CGSize(width: 2304, height: 3072))
        #expect(slide.cells[1].image == nil)
        #expect(image.fileFormat == .jpeg)
        #expect(slide.layers.isEmpty)
        #expect(slide.blur == 0)
        #expect(slide.style == .standard)
    }

    @Test func readsVersion2() throws {
        let project = try ProjectFile.decode(Data(Self.version2.utf8))
        #expect(project.slides.map(\.layout) == [.single, .panorama])
        #expect(project.slides.map(\.span) == [1, 4])
        #expect(project.carouselSlideCount == 5)
        let image = try #require(project.slides[1].cells.first?.image)
        #expect(image.pixelSize == CGSize(width: 4000, height: 1000))
        #expect(image.fileFormat == .jpeg)
        #expect(project.slides.allSatisfy { $0.layers.isEmpty && $0.blur == 0 && $0.style == .standard })
    }

    @Test func readsVersion3() throws {
        let project = try ProjectFile.decode(Data(Self.version3.utf8))
        let slide = try #require(project.slides.first)
        #expect(slide.blur == 0.02)
        #expect(slide.layers.count == 2)
        guard case .text(let text) = slide.layers[0].content, case .image(let picture) = slide.layers[1].content else {
            Issue.record("Expected a text layer under a picture")
            return
        }
        #expect(text == TextLayer(text: "Lisbon", font: .serif, color: .white, alignment: .leading, hasShadow: true))
        #expect(slide.layers[0].placement == LayerPlacement(centerX: 0.25, centerY: 0.2, scale: 1.5, rotation: -0.1))
        #expect(picture.image.fileFormat == .png)
        #expect(picture.image.fileName == "6A1F2B3C-0000-4000-8000-000000000006.png")
        #expect(picture.borderWidth == 0.05)
        #expect(!picture.hasShadow)
        #expect(picture.borderStyle == .plain)
        #expect(project.images.map(\.fileFormat) == [.jpeg, .png])
        #expect(slide.style == .standard)
    }

    @Test func readsVersion4() throws {
        let project = try ProjectFile.decode(Data(Self.version4.utf8))
        #expect(project.aspectRatio == .square)
        #expect(project.slides.map(\.style) == [.standard, SlideStyle(spacing: 0.02, border: 0.03, background: .black)])
        #expect(project.slides.map(\.blur) == [0, 0.02])
    }

    @Test func readsVersion5() throws {
        let project = try ProjectFile.decode(Data(Self.version5.utf8))
        #expect(project.aspectRatio == AspectRatio(width: 5, height: 7, pixelWidth: 2000, pixelHeight: 2800))
        #expect(project.slides.map(\.style) == [.standard, SlideStyle(spacing: 0.02, border: 0.03, background: .black)])
        // Writes back as read, as the current version, with the style on every slide, even the
        // standard one.
        let current = Self.version5.replacingOccurrences(
            of: "\"formatVersion\" : 5",
            with: "\"formatVersion\" : \(ProjectFile.currentFormatVersion)"
        )
        #expect(String(bytes: try ProjectFile.encode(project), encoding: .utf8) == current)
    }

    @Test func readsVersion6() throws {
        let project = try ProjectFile.decode(Data(Self.version6.utf8))
        #expect(project.tray.map(\.image.assetIdentifier) == ["ABC123/L0/001", nil])
        #expect(project.tray[1].image.pixelSize == CGSize(width: 4096, height: 1024))
        let clone = try #require(project.slides.first?.cells.first?.image)
        #expect(clone.trayPhotoID == project.tray[0].id)
        #expect(project.slidesHoldingTrayPhotos == [project.tray[0].id: [0]])
        #expect(project.images.map(\.id) == [clone.id] + project.tray.map(\.image.id))
        #expect(String(bytes: try ProjectFile.encode(project), encoding: .utf8) == Self.version6)
    }

    /// Versions 1 to 4 saved only presets, by name.
    @Test func readsEveryPresetByItsOldName() throws {
        for preset in AspectRatio.presets {
            let json = Self.version4.replacingOccurrences(of: "\"aspectRatio\" : \"1:1\"", with: "\"aspectRatio\" : \"\(preset.label)\"")
            #expect(try ProjectFile.decode(Data(json.utf8)).aspectRatio == preset)
        }
    }

    /// No build makes a shape past its limits, nor saved any but a preset by name.
    @Test func refusesAShapeNoBuildMakes() {
        let shapes = [
            Self.version4.replacingOccurrences(of: "\"aspectRatio\" : \"1:1\"", with: "\"aspectRatio\" : \"5:7\""),
            Self.version5.replacingOccurrences(of: "\"height\" : 7", with: "\"height\" : 1"),
            Self.version5.replacingOccurrences(of: "\"pixelHeight\" : 2800", with: "\"pixelHeight\" : 5000"),
            Self.version5.replacingOccurrences(of: "\"pixelHeight\" : 2800", with: "\"pixelHeight\" : 2900")
        ]
        for json in shapes {
            #expect(throws: ProjectFile.ReadError.damaged) {
                try ProjectFile.decode(Data(json.utf8))
            }
        }
    }

    /// Versions 1 to 3 kept one style on the project, which every slide takes.
    @Test func movesTheProjectStyleOntoEverySlide() throws {
        let json = Self.version2
            .replacingOccurrences(of: "\"spacing\" : 0.01", with: "\"spacing\" : 0.04")
            .replacingOccurrences(of: "\"blue\" : 1", with: "\"blue\" : 0")
            .replacingOccurrences(of: "\"green\" : 1", with: "\"green\" : 0")
            .replacingOccurrences(of: "\"red\" : 1", with: "\"red\" : 0")
        let project = try ProjectFile.decode(Data(json.utf8))
        let style = SlideStyle(spacing: 0.04, border: 0, background: .black)
        #expect(project.slides.map(\.style) == [style, style])
    }

    /// Every build before version 4 wrote the project's style, so a file without it is damaged.
    @Test func refusesAnOldProjectWithoutItsStyle() {
        let json = Self.version2.replacingOccurrences(of: "\"style\"", with: "\"unused\"")
        #expect(throws: ProjectFile.ReadError.damaged) {
            try ProjectFile.decode(Data(json.utf8))
        }
    }

    /// A style past its range is clamped, whether a slide's own or one an older project held.
    @Test func clampsStyles() throws {
        let legacy = Self.version3.replacingOccurrences(of: "\"spacing\" : 0.01", with: "\"spacing\" : 0.5")
        #expect(try ProjectFile.decode(Data(legacy.utf8)).slides[0].style.spacing == SlideStyle.maximumSpacing)
        let current = Self.version4.replacingOccurrences(of: "\"border\" : 0.03", with: "\"border\" : -1")
        #expect(try ProjectFile.decode(Data(current.utf8)).slides[1].style.border == 0)
    }

    /// Layer values out of range are clamped rather than refused, which keeps every photo and
    /// layer, and a text layer with no text, which no build saves, is dropped.
    @Test func clampsLayersAndDropsBlankText() throws {
        let json = Self.version3
            .replacingOccurrences(of: "\"text\" : \"Lisbon\"", with: "\"text\" : \"  \"")
            .replacingOccurrences(of: "\"centerX\" : 0.7", with: "\"centerX\" : 7.5")
            .replacingOccurrences(of: "\"scale\" : 0.75", with: "\"scale\" : 40")
            .replacingOccurrences(of: "\"borderWidth\" : 0.05", with: "\"borderWidth\" : 3")
            .replacingOccurrences(of: "\"blur\" : 0.02", with: "\"blur\" : 0.9")

        let slide = try #require(try ProjectFile.decode(Data(json.utf8)).slides.first)

        #expect(slide.layers.count == 1)
        let picture = try #require(slide.layers.first)
        #expect(picture.placement.centerX == 0.5)
        #expect(picture.placement.scale == LayerPlacement.scales.upperBound)
        guard case .image(let image) = picture.content else {
            Issue.record("Expected a picture")
            return
        }
        #expect(image.borderWidth == ImageLayer.maximumBorderWidth)
        #expect(slide.blur == Slide.maximumBlur)
    }

    @Test func refusesASpanItsLayoutCantHave() {
        let spans = [
            Self.version2.replacingOccurrences(of: "\"span\" : 4", with: "\"span\" : 1"),
            Self.version2.replacingOccurrences(of: "\"span\" : 4", with: "\"span\" : 11"),
            Self.version2.replacingOccurrences(of: "\"span\" : 1", with: "\"span\" : 2")
        ]
        for json in spans {
            #expect(throws: ProjectFile.ReadError.damaged) {
                try ProjectFile.decode(Data(json.utf8))
            }
        }
    }

    @Test func roundTrips() throws {
        let gathered = TrayPhoto(image: PlacedImage(assetIdentifier: "A/B/C", pixelWidth: 3072, pixelHeight: 2048))
        let wide = TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 4000, pixelHeight: 1000))
        let image = PlacedImage(
            assetIdentifier: "A/B/C",
            pixelWidth: 3072,
            pixelHeight: 2048,
            crop: ImageCrop(scale: 2, centerX: 0.4, centerY: 0.6),
            trayPhotoID: gathered.id
        )
        let sticker = PlacedImage(assetIdentifier: nil, pixelWidth: 500, pixelHeight: 500, fileFormat: .png)
        let framed = SlideStyle(spacing: 0.03, border: 0.02, background: RGBColor(red: 0.1, green: 0.2, blue: 0.3))
        let flush = SlideStyle(spacing: 0, border: 0, background: .black)
        let project = Project(
            name: "Trip",
            aspectRatio: try #require(AspectRatio(width: 2.25, height: 1.5, pixelWidth: 3000, pixelHeight: 2000)),
            slides: [
                Slide(layout: .grid, cells: [Cell(image: image), Cell(), Cell(), Cell()], style: framed),
                Slide(
                    layout: .panorama,
                    span: 6,
                    layers: [
                        Layer(content: .text(TextLayer(text: "Across", font: .script, isHighlighted: true)), placement: LayerPlacement(centerX: 3)),
                        Layer(content: .image(ImageLayer(image: sticker, borderWidth: 0.04, borderStyle: .instant, blur: 0.01, hasShadow: true)))
                    ],
                    blur: 0.01,
                    style: flush
                )
            ],
            tray: [gathered, wide],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let data = try ProjectFile.encode(project)
        #expect(try ProjectFile.decode(data) == project)
        // Asset identifiers hold slashes, which read better unescaped.
        let json = try #require(String(bytes: data, encoding: .utf8))
        #expect(json.contains("\"A/B/C\""))
    }

    @Test func refusesANewerVersion() {
        let version = ProjectFile.currentFormatVersion + 1
        let newer = Self.version2.replacingOccurrences(of: "\"formatVersion\" : 2", with: "\"formatVersion\" : \(version)")
        #expect(throws: ProjectFile.ReadError.newerVersion(version)) {
            try ProjectFile.decode(Data(newer.utf8))
        }
    }

    @Test func refusesUnversionedOrUnparseableData() {
        #expect(throws: ProjectFile.ReadError.damaged) {
            try ProjectFile.decode(Data(#"{"project": {}}"#.utf8))
        }
        #expect(throws: ProjectFile.ReadError.damaged) {
            try ProjectFile.decode(Data("not json".utf8))
        }
        let unknownLayout = Self.version1.replacingOccurrences(of: "twoColumns", with: "hexagons")
        #expect(throws: ProjectFile.ReadError.damaged) {
            try ProjectFile.decode(Data(unknownLayout.utf8))
        }
    }

    @Test func padsMissingCellsButRefusesExtraOnes() throws {
        let short = Self.version1.replacingOccurrences(of: "\"twoColumns\"", with: "\"grid\"")
        let padded = try ProjectFile.decode(Data(short.utf8))
        #expect(padded.slides[0].cells.count == 4)
        #expect(padded.slides[0].cells[0].image != nil)

        let long = Self.version1.replacingOccurrences(of: "\"twoColumns\"", with: "\"single\"")
        #expect(throws: ProjectFile.ReadError.damaged) {
            try ProjectFile.decode(Data(long.utf8))
        }
    }
}
