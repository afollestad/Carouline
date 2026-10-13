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

/// Makes the app's own copy of a photo: upright, no larger than its slides can use, as a JPEG.
nonisolated enum ImageImporter {
    /// Room for a full zoom into the smallest cells of a 1080-pixel export, while a 48-megapixel
    /// photo's copy stays near a tenth of its size.
    static let maximumPixelSize = 3072

    /// The most of a photo a copy keeps.
    struct CopyLimit: Hashable, Sendable {
        /// The export height of the project's slides, which a panorama of the photo fills.
        let slideHeight: Int
        /// Whether the copy fills a panorama rather than a cell.
        let isPanorama: Bool

        /// As wide as the widest panorama's export.
        private static let panoramaSide = 1080 * Slide.panoramaSpans.upperBound
        /// About 96 MB decoded, so a photo nearer square isn't kept whole.
        private static let panoramaPixels = 24_000_000.0

        /// The longer side of the copy of an upright `width` by `height` photo. A panorama's copy
        /// keeps up to the widest panorama's export, within `panoramaPixels`. So does a cell's
        /// when the photo is too wide for `maximumPixelSize` to fill a panorama of these slides,
        /// so it stays sharp if the slide becomes one; any other cell's keeps `maximumPixelSize`.
        func longestSide(width: Int, height: Int) -> Int {
            let isWide = height > 0 && width * slideHeight > height * maximumPixelSize
            guard isPanorama || isWide else {
                return maximumPixelSize
            }
            guard width > 0, height > 0 else {
                return Self.panoramaSide
            }
            let aspect = Double(max(width, height)) / Double(min(width, height))
            return min(Self.panoramaSide, Int((Self.panoramaPixels * aspect).squareRoot()))
        }
    }

    enum ImportError: Error {
        case unreadable
        case unwritable
    }

    /// Writes `source`'s copy, within `limit`, to `destination` and returns its pixel size.
    @concurrent
    static func makeCopy(of source: PhotoSource, at destination: URL, limit: CopyLimit) async throws -> CGSize {
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
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let storedWidth = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let storedHeight = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        // EXIF orientations 5 to 8 turn the photo a quarter, so it stands the other way up.
        let isTurned = (5...8).contains(properties?[kCGImagePropertyOrientation] as? Int ?? 1)
        let width = isTurned ? storedHeight : storedWidth
        let height = isTurned ? storedWidth : storedHeight
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
