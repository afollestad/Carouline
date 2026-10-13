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
    /// A library original's data, as stored.
    case data(Data)
}

/// Makes the app's own copy of a photo: upright, no larger than its slides can use, as a JPEG,
/// or as a PNG for a layer's picture with transparency to keep.
nonisolated enum ImageImporter {
    /// Room for a full zoom into the smallest cells of a 1080-pixel export, while a 48-megapixel
    /// photo's copy stays near a tenth of its size.
    static let maximumPixelSize = 3072
    /// A layer's picture at its largest in a 1080-pixel export: its longer side half a slide at
    /// its natural size, `LayerGeometry.pictureSide`, times the largest scale, which is four.
    static let maximumLayerPixelSize = 2160

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

    /// A copy written out: its pixel size, upright, and how it's encoded.
    struct Copy: Hashable, Sendable {
        let size: CGSize
        let format: ImageFileFormat
    }

    /// Writes `source`'s copy, within `limit`, to `destination`.
    @concurrent
    static func makeCopy(of source: PhotoSource, at destination: URL, limit: CopyLimit) async throws -> Copy {
        let image = try upright(source, longestSide: limit.longestSide)
        try write(image, to: destination, format: .jpeg)
        return Copy(size: CGSize(width: image.width, height: image.height), format: .jpeg)
    }

    /// Writes `source`'s copy for a layer to `destination`, no larger than a layer draws: a PNG
    /// when a file or a library original has transparency to keep, as a sticker or a logo cut
    /// out of its background does, and otherwise a JPEG, which is far smaller. A camera capture
    /// has none to keep.
    @concurrent
    static func makeLayerCopy(of source: PhotoSource, at destination: URL) async throws -> Copy {
        let image = try upright(source) { _, _ in maximumLayerPixelSize }
        let format: ImageFileFormat = hasTransparency(image) ? .png : .jpeg
        try write(image, to: destination, format: format)
        return Copy(size: CGSize(width: image.width, height: image.height), format: format)
    }

    /// Whether any of `image`'s pixels is less than opaque. An alpha channel alone doesn't say,
    /// since screenshots and many other opaque PNGs carry one.
    static func hasTransparency(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            break
        }
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else {
            return true
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else {
            return true
        }
        let alphas = UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height)
        return alphas.contains { $0 < .max }
    }

    /// `source` decoded upright, its longer side no more than `longestSide` gives for its upright
    /// width and height.
    private static func upright(_ source: PhotoSource, longestSide: (Int, Int) -> Int) throws -> CGImage {
        let imageSource: CGImageSource? = switch source {
        case .file(let url):
            CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        case .image(let image):
            // JPEG data keeps the capture's orientation as EXIF, which the thumbnail below applies.
            image.jpegData(compressionQuality: 1).flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
        case .data(let data):
            CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
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
            kCGImageSourceThumbnailMaxPixelSize: longestSide(width, height)
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw ImportError.unreadable
        }
        return image
    }

    /// Encodes `image` in `format`, keeping its color profile, so a wide-gamut photo stays wide.
    /// A PNG keeps its transparency; a JPEG has none, and ImageIO flattens it onto white.
    static func write(_ image: CGImage, to destination: URL, format: ImageFileFormat, quality: Double = 0.9) throws {
        let type = switch format {
        case .jpeg: UTType.jpeg
        case .png: UTType.png
        }
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil) else {
            throw ImportError.unwritable
        }
        let options = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary : nil
        CGImageDestinationAddImage(output, image, options)
        guard CGImageDestinationFinalize(output) else {
            throw ImportError.unwritable
        }
    }
}
