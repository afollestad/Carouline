//
//  PhotoKitLibraryTests.swift
//  CaroulineTests
//

import Foundation
import ImageIO
import Testing
@testable import Carouline

struct PhotoKitLibraryTests {
    private let temporary = TemporaryDirectory("PhotoKitLibraryTests")

    private func orientation(of data: Data) -> Int? {
        CGImageSourceCreateWithData(data as CFData, nil)
            .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] }?[kCGImagePropertyOrientation] as? Int
    }

    /// A photo whose own metadata says otherwise takes the orientation Photos shows it in.
    @Test func turnsAPhotoAsPhotosShowsIt() throws {
        try FileManager.default.createDirectory(at: temporary.url, withIntermediateDirectories: true)
        let url = temporary.url.appending(path: "photo.jpg")
        try TestImages.writeJPEG(width: 300, height: 200, to: url)
        let data = try Data(contentsOf: url)

        let turned = PhotoKitLibrary.turned(data, to: .right)

        #expect(orientation(of: turned) == Int(CGImagePropertyOrientation.right.rawValue))
        #expect(PhotoKitLibrary.turned(turned, to: .right) == turned)
    }
}
