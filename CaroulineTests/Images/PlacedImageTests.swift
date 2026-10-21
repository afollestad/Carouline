//
//  PlacedImageTests.swift
//  CaroulineTests
//

import Foundation
import Testing
@testable import Carouline

struct PlacedImageTests {
    private static let id = UUID(uuid: (0x6A, 0x1F, 0x2B, 0x3C, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, 3))

    private func encoded(_ image: PlacedImage) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try #require(String(data: encoder.encode(image), encoding: .utf8))
    }

    /// A JPEG copy saves as copies always have, so projects of them don't change on disk.
    @Test func encodesAJPEGAsBefore() throws {
        let image = PlacedImage(id: Self.id, assetIdentifier: "ABC123/L0/001", pixelWidth: 2304, pixelHeight: 3072)

        #expect(try encoded(image) == """
            {
              "assetIdentifier" : "ABC123/L0/001",
              "crop" : {
                "centerX" : 0.5,
                "centerY" : 0.5,
                "scale" : 1
              },
              "id" : "6A1F2B3C-0000-4000-8000-000000000003",
              "pixelHeight" : 3072,
              "pixelWidth" : 2304
            }
            """)
        #expect(image.fileName == "6A1F2B3C-0000-4000-8000-000000000003.jpg")
    }

    @Test func keepsAPNGsFormat() throws {
        let image = PlacedImage(id: Self.id, assetIdentifier: nil, pixelWidth: 400, pixelHeight: 300, fileFormat: .png)

        let json = try encoded(image)
        let decoded = try JSONDecoder().decode(PlacedImage.self, from: Data(json.utf8))

        #expect(json.contains(#""fileFormat" : "png""#))
        #expect(decoded == image)
        #expect(image.fileName == "6A1F2B3C-0000-4000-8000-000000000003.png")
    }

    /// Only a clone of a tray photo names one, so other copies save as they did before trays.
    @Test func keepsTheTrayPhotoItCameFrom() throws {
        let trayPhotoID = UUID()
        let clone = PlacedImage(id: Self.id, assetIdentifier: nil, pixelWidth: 400, pixelHeight: 300, trayPhotoID: trayPhotoID)

        let json = try encoded(clone)
        let decoded = try JSONDecoder().decode(PlacedImage.self, from: Data(json.utf8))

        #expect(json.contains(#""trayPhotoID" : "\#(trayPhotoID.uuidString)""#))
        #expect(decoded == clone)
        #expect(try !encoded(PlacedImage(id: Self.id, assetIdentifier: nil, pixelWidth: 400, pixelHeight: 300)).contains("trayPhotoID"))
    }
}
