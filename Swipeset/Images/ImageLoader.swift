//
//  ImageLoader.swift
//  Swipeset
//

import ImageIO
import SwiftUI

/// A copy to decode, at no more than `maxPixelSize` on its longer side.
nonisolated struct ImageRequest: Hashable, Sendable {
    let projectID: UUID
    let imageID: UUID
    let fileFormat: ImageFileFormat
    /// The copy's own size, which a decode never exceeds.
    let pixelWidth: Int
    let pixelHeight: Int
    let maxPixelSize: Int

    init(projectID: UUID, image: PlacedImage, displayedPixels: CGFloat) {
        self.projectID = projectID
        imageID = image.id
        fileFormat = image.fileFormat
        pixelWidth = image.pixelWidth
        pixelHeight = image.pixelHeight
        maxPixelSize = Self.bucket(for: displayedPixels)
    }

    /// Rounds a size up to one of a few, so a cell resized or zoomed a little reuses its decode
    /// rather than making another. Capped at a cell's copy size even for a panorama's larger
    /// copy, since no card on screen shows more, and its whole copy decodes to up to 96 MB.
    static func bucket(for pixels: CGFloat) -> Int {
        [256, 512, 1024, 2048].first { CGFloat($0) >= pixels } ?? ImageImporter.maximumPixelSize
    }
}

/// Decodes image copies at the size their cells show them.
nonisolated protocol ImageLoading: Sendable {
    /// The image if it's already decoded, so a cell can show it on its first frame.
    func cachedImage(_ request: ImageRequest) -> CGImage?
    /// The image decoded, or nil when its copy is missing or unreadable.
    func image(_ request: ImageRequest) async -> CGImage?
}

/// Decodes copies from a store's folders, keeping recent decodes in memory.
nonisolated final class DiskImageLoader: ImageLoading, @unchecked Sendable {
    private let paths: ProjectPaths
    /// `NSCache` is safe to use from any thread, which is what makes this class `Sendable`.
    private let cache = NSCache<NSString, CGImage>()

    init(paths: ProjectPaths) {
        self.paths = paths
        // About forty decodes at a 2048-pixel cell's size, and it empties under memory pressure.
        cache.totalCostLimit = 150 * 1024 * 1024
    }

    func cachedImage(_ request: ImageRequest) -> CGImage? {
        cache.object(forKey: key(for: request))
    }

    @concurrent
    func image(_ request: ImageRequest) async -> CGImage? {
        if let cached = cachedImage(request) {
            return cached
        }
        let fileName = PlacedImage.fileName(for: request.imageID, format: request.fileFormat)
        let url = paths.imageFile(named: fileName, in: request.projectID)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: request.maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        cache.setObject(image, forKey: key(for: request), cost: image.bytesPerRow * image.height)
        return image
    }

    private func key(for request: ImageRequest) -> NSString {
        "\(request.imageID.uuidString)-\(request.maxPixelSize)" as NSString
    }
}

/// Draws a sample photo for every request, for previews and snapshots, which have no files.
nonisolated struct MockImageLoader: ImageLoading {
    /// Images that load as missing.
    var missing: Set<UUID> = []

    func cachedImage(_ request: ImageRequest) -> CGImage? {
        guard !missing.contains(request.imageID) else {
            return nil
        }
        return switch request.fileFormat {
        case .png: SampleImages.sticker(for: request.imageID, width: request.pixelWidth, height: request.pixelHeight, maxPixelSize: 512)
        case .jpeg: SampleImages.image(for: request.imageID, width: request.pixelWidth, height: request.pixelHeight, maxPixelSize: 512)
        }
    }

    func image(_ request: ImageRequest) async -> CGImage? {
        cachedImage(request)
    }
}

extension EnvironmentValues {
    /// Where cells get their photos. The app sets a `DiskImageLoader` for its store; previews keep
    /// this sample one.
    @Entry var imageLoader: any ImageLoading = MockImageLoader()
}
