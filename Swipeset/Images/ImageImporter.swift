//
//  ImageImporter.swift
//  Swipeset
//

import ImageIO
import UIKit
import UniformTypeIdentifiers

/// A photo on its way into a project.
nonisolated enum PhotoSource: Sendable {
    /// A file, as the photo picker hands one over.
    case file(URL)
    /// A camera capture, which never reaches a file.
    case image(UIImage)
}

/// Makes the app's own copy of a photo: upright, no larger than a cell can use, as a JPEG.
nonisolated enum ImageImporter {
    /// Room for a full zoom into the smallest cells of a 1080-pixel export, while a 48-megapixel
    /// photo's copy stays near a tenth of its size.
    static let maximumPixelSize = 3072

    enum ImportError: Error {
        case unreadable
        case unwritable
    }

    /// Writes `source`'s copy to `destination` and returns its pixel size.
    @concurrent
    static func makeCopy(of source: PhotoSource, at destination: URL) async throws -> CGSize {
        let imageSource: CGImageSource? = switch source {
        case .file(let url):
            CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        case .image(let image):
            // JPEG data keeps the capture's orientation as EXIF, which the thumbnail below applies.
            image.jpegData(compressionQuality: 1).flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bakes the EXIF orientation into the pixels, so the copy needs none.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        guard let imageSource, let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ImportError.unreadable
        }
        try write(image, to: destination)
        return CGSize(width: image.width, height: image.height)
    }

    /// Encodes `image` as a JPEG, keeping its color profile, so a wide-gamut photo stays wide.
    static func write(_ image: CGImage, to destination: URL, quality: Double = 0.9) throws {
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImportError.unwritable
        }
        CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(output) else {
            throw ImportError.unwritable
        }
    }
}
