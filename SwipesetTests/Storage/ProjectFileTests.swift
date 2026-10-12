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

    @Test func readsVersion1() throws {
        let project = try ProjectFile.decode(Data(Self.version1.utf8))
        #expect(project.name == "Lisbon")
        #expect(project.aspectRatio == .portrait)
        #expect(project.style == .standard)
        #expect(project.createdAt == Date(timeIntervalSince1970: 1_791_817_200))
        let slide = try #require(project.slides.first)
        #expect(slide.layout == .twoColumns)
        #expect(slide.cells.count == 2)
        let image = try #require(slide.cells[0].image)
        #expect(image.assetIdentifier == "ABC123/L0/001")
        #expect(image.crop == ImageCrop(scale: 1.5, centerX: 0.25, centerY: 0.5))
        #expect(image.pixelSize == CGSize(width: 2304, height: 3072))
        #expect(slide.cells[1].image == nil)
    }

    @Test func roundTrips() throws {
        let image = PlacedImage(assetIdentifier: "A/B/C", pixelWidth: 3072, pixelHeight: 2048, crop: ImageCrop(scale: 2, centerX: 0.4, centerY: 0.6))
        let project = Project(
            name: "Trip",
            aspectRatio: .landscape,
            style: SlideStyle(spacing: 0.03, border: 0.02, background: RGBColor(red: 0.1, green: 0.2, blue: 0.3)),
            slides: [Slide(layout: .grid, cells: [Cell(image: image), Cell(), Cell(), Cell()])],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let data = try ProjectFile.encode(project)
        #expect(try ProjectFile.decode(data) == project)
        // Asset identifiers hold slashes, which read better unescaped.
        let json = try #require(String(bytes: data, encoding: .utf8))
        #expect(json.contains("\"A/B/C\""))
    }

    @Test func refusesANewerVersion() {
        let newer = Self.version1.replacingOccurrences(of: "\"formatVersion\" : 1", with: "\"formatVersion\" : 2")
        #expect(throws: ProjectFile.ReadError.newerVersion(2)) {
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
