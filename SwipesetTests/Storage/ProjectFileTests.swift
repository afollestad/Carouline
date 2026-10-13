//
//  ProjectFileTests.swift
//  SwipesetTests
//

import Foundation
import Testing
@testable import Swipeset

struct ProjectFileTests {
    /// A project as version 1 saves it. Every build must keep reading it.
    private static let version1 = """
        {
          "formatVersion" : 1,
          "project" : {
            "aspectRatio" : "4:5",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "cells" : [
                  {
                    "image" : {
                      "assetIdentifier" : "ABC123/L0/001",
                      "crop" : {
                        "centerX" : 0.25,
                        "centerY" : 0.5,
                        "scale" : 1.5
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                      "pixelHeight" : 3072,
                      "pixelWidth" : 2304
                    }
                  },
                  {

                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layout" : "twoColumns"
              }
            ],
            "style" : {
              "background" : {
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "border" : 0,
              "spacing" : 0.01
            }
          }
        }
        """

    /// A project as version 2 saves it, with a slide and a panorama. Every build must keep reading it.
    private static let version2 = """
        {
          "formatVersion" : 2,
          "project" : {
            "aspectRatio" : "4:5",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "cells" : [
                  {

                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layout" : "single",
                "span" : 1
              },
              {
                "cells" : [
                  {
                    "image" : {
                      "assetIdentifier" : "ABC123/L0/001",
                      "crop" : {
                        "centerX" : 0.5,
                        "centerY" : 0.5,
                        "scale" : 1
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000004",
                      "pixelHeight" : 1000,
                      "pixelWidth" : 4000
                    }
                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                "layout" : "panorama",
                "span" : 4
              }
            ],
            "style" : {
              "background" : {
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "border" : 0,
              "spacing" : 0.01
            }
          }
        }
        """

    /// A project as version 3 saves it, with a blurred slide under a text layer and a PNG
    /// picture layer. Every build must keep reading it.
    private static let version3 = """
        {
          "formatVersion" : 3,
          "project" : {
            "aspectRatio" : "4:5",
            "createdAt" : "2026-10-12T15:00:00Z",
            "id" : "6A1F2B3C-0000-4000-8000-000000000001",
            "modifiedAt" : "2026-10-12T16:30:00Z",
            "name" : "Lisbon",
            "slides" : [
              {
                "blur" : 0.02,
                "cells" : [
                  {
                    "image" : {
                      "crop" : {
                        "centerX" : 0.5,
                        "centerY" : 0.5,
                        "scale" : 2
                      },
                      "id" : "6A1F2B3C-0000-4000-8000-000000000003",
                      "pixelHeight" : 3072,
                      "pixelWidth" : 2304
                    }
                  }
                ],
                "id" : "6A1F2B3C-0000-4000-8000-000000000002",
                "layers" : [
                  {
                    "content" : {
                      "text" : {
                        "alignment" : "leading",
                        "color" : {
                          "blue" : 1,
                          "green" : 1,
                          "red" : 1
                        },
                        "font" : "serif",
                        "hasShadow" : true,
                        "isHighlighted" : false,
                        "text" : "Lisbon"
                      }
                    },
                    "id" : "6A1F2B3C-0000-4000-8000-000000000004",
                    "placement" : {
                      "centerX" : 0.25,
                      "centerY" : 0.2,
                      "rotation" : -0.1,
                      "scale" : 1.5
                    }
                  },
                  {
                    "content" : {
                      "image" : {
                        "blur" : 0,
                        "borderColor" : {
                          "blue" : 1,
                          "green" : 1,
                          "red" : 1
                        },
                        "borderWidth" : 0.05,
                        "image" : {
                          "crop" : {
                            "centerX" : 0.5,
                            "centerY" : 0.5,
                            "scale" : 1
                          },
                          "fileFormat" : "png",
                          "id" : "6A1F2B3C-0000-4000-8000-000000000006",
                          "pixelHeight" : 600,
                          "pixelWidth" : 800
                        }
                      }
                    },
                    "id" : "6A1F2B3C-0000-4000-8000-000000000005",
                    "placement" : {
                      "centerX" : 0.7,
                      "centerY" : 0.75,
                      "rotation" : 0,
                      "scale" : 0.75
                    }
                  }
                ],
                "layout" : "single",
                "span" : 1
              }
            ],
            "style" : {
              "background" : {
                "blue" : 1,
                "green" : 1,
                "red" : 1
              },
              "border" : 0,
              "spacing" : 0.01
            }
          }
        }
        """

    @Test func readsVersion1() throws {
        let project = try ProjectFile.decode(Data(Self.version1.utf8))
        #expect(project.name == "Lisbon")
        #expect(project.aspectRatio == .portrait)
        #expect(project.style == .standard)
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
    }

    @Test func readsVersion2() throws {
        let project = try ProjectFile.decode(Data(Self.version2.utf8))
        #expect(project.slides.map(\.layout) == [.single, .panorama])
        #expect(project.slides.map(\.span) == [1, 4])
        #expect(project.carouselSlideCount == 5)
        let image = try #require(project.slides[1].cells.first?.image)
        #expect(image.pixelSize == CGSize(width: 4000, height: 1000))
        #expect(image.fileFormat == .jpeg)
        #expect(project.slides.allSatisfy { $0.layers.isEmpty && $0.blur == 0 })
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
        #expect(project.images.map(\.fileFormat) == [.jpeg, .png])
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
        let image = PlacedImage(assetIdentifier: "A/B/C", pixelWidth: 3072, pixelHeight: 2048, crop: ImageCrop(scale: 2, centerX: 0.4, centerY: 0.6))
        let sticker = PlacedImage(assetIdentifier: nil, pixelWidth: 500, pixelHeight: 500, fileFormat: .png)
        let project = Project(
            name: "Trip",
            aspectRatio: .landscape,
            style: SlideStyle(spacing: 0.03, border: 0.02, background: RGBColor(red: 0.1, green: 0.2, blue: 0.3)),
            slides: [
                Slide(layout: .grid, cells: [Cell(image: image), Cell(), Cell(), Cell()]),
                Slide(
                    layout: .panorama,
                    span: 6,
                    layers: [
                        Layer(content: .text(TextLayer(text: "Across", font: .script, isHighlighted: true)), placement: LayerPlacement(centerX: 3)),
                        Layer(content: .image(ImageLayer(image: sticker, borderWidth: 0.04, blur: 0.01)))
                    ],
                    blur: 0.01
                )
            ],
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
