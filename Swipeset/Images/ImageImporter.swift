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

    /// The most of a photo a copy keeps.
    struct CopyLimit: Hashable, Sendable {
        let longestSide: Int
        /// Nil for no limit past `longestSide`.
        let maximumPixels: Int?

        static let cell = CopyLimit(longestSide: maximumPixelSize, maximumPixels: nil)
        /// As wide as the widest panorama's export, for a photo as wide as it, but no more than
        /// 24 megapixels, about 96 MB decoded, so a photo nearer square isn't kept whole.
        static let panorama = CopyLimit(longestSide: 1080 * Slide.panoramaSpans.upperBound, maximumPixels: 24_000_000)

        /// The longer side of a copy of a `width` by `height` photo, or `longestSide` when the
        /// photo's size isn't known.
        func longestSide(width: Int, height: Int) -> Int {
            guard let maximumPixels, width > 0, height > 0 else {
                return longestSide
            }
            let aspect = Double(max(width, height)) / Double(min(width, height))
            return min(longestSide, Int((Double(maximumPixels) * aspect).squareRoot()))
        }
    }

    enum ImportError: Error {
        case unreadable
        case unwritable
    }

    /// Writes `source`'s copy, within `limit`, to `destination` and returns its pixel size.
    @concurrent
    static func makeCopy(of source: PhotoSource, at destination: URL, limit: CopyLimit = .cell) async throws -> CGSize {
        let imageSource: CGImageSource? = switch source {
        case .file(let url):
            CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        case .image(let image):
            // JPEG data keeps the capture's orientation as EXIF, which the thumbnail below applies.
            image.jpegData(compressionQuality: 1).flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
        }
        guard let imageSource else {
            throw ImportError.unreadable
        }
        // Upright or not, the photo's sides keep the same proportion, which is all the limit needs.
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bakes the EXIF orientation into the pixels, so the copy needs none.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limit.longestSide(width: width, height: height)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
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
