//
//  ImageLoader.swift
//  Carouline
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

    /// `cellPixels` is the longer side of the cell showing the photo, which lifts the cap past a
    /// preset's cell copy for a panorama's, as wide as several slides.
    init(projectID: UUID, image: PlacedImage, displayedPixels: CGFloat, cellPixels: CGFloat = 0) {
        self.projectID = projectID
        imageID = image.id
        fileFormat = image.fileFormat
        pixelWidth = image.pixelWidth
        pixelHeight = image.pixelHeight
        maxPixelSize = Self.bucket(for: displayedPixels, upTo: max(CGFloat(ImageImporter.maximumPixelSize), cellPixels))
    }

    /// The sizes a decode rounds up to: up to a preset's cell copy, then steps of about half again
    /// for a panorama's, as wide as up to ten slides, to 12,288 pixels, inside a texture's 16,384.
    static let buckets = [256, 512, 1024, 2048, ImageImporter.maximumPixelSize, 4096, 6144, 8192, 12_288]

    /// Rounds a size, no larger than `cap`, up to one of `buckets`, so a cell resized or zoomed a
    /// little reuses its decode rather than making another. Capped at a preset's cell copy size,
    /// or a panorama's cell, even for a wider export's larger copy, since a zoomed photo shows no
    /// more than its cell, and a whole copy decodes to up to 96 MB.
    static func bucket(for pixels: CGFloat, upTo cap: CGFloat = CGFloat(ImageImporter.maximumPixelSize)) -> Int {
        buckets.first { CGFloat($0) >= min(pixels, cap) } ?? 12_288
    }
}

/// Decodes image copies at the size their cells show them.
nonisolated protocol ImageLoading: Sendable {
    /// The image if it's already decoded, so a cell can show it on its first frame.
    func cachedImage(_ request: ImageRequest) -> CGImage?
    /// The image decoded, or nil when its copy is missing or unreadable.
    func image(_ request: ImageRequest) async -> CGImage?
}

extension ImageLoading {
    /// The largest decode of `image` already in memory, at any of the sizes a request rounds to,
    /// for a view that must show the photo on its first frame and can't wait for a decode at its
    /// own size, as a drag's preview can't.
    func anyCachedImage(of image: PlacedImage, in projectID: UUID) -> CGImage? {
        ImageRequest.buckets.reversed().lazy.compactMap { size in
            cachedImage(ImageRequest(projectID: projectID, image: image, displayedPixels: CGFloat(size), cellPixels: CGFloat(size)))
        }.first
    }
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
    /// Images that never finish loading, as a slow decode shows until it lands.
    var loading: Set<UUID> = []

    func cachedImage(_ request: ImageRequest) -> CGImage? {
        guard !missing.contains(request.imageID), !loading.contains(request.imageID) else {
            return nil
        }
        return switch request.fileFormat {
        case .png: SampleImages.sticker(for: request.imageID, width: request.pixelWidth, height: request.pixelHeight, maxPixelSize: 512)
        case .jpeg: SampleImages.image(for: request.imageID, width: request.pixelWidth, height: request.pixelHeight, maxPixelSize: 512)
        }
    }

    func image(_ request: ImageRequest) async -> CGImage? {
        if loading.contains(request.imageID) {
            // Until the view waiting on it goes, which cancels the wait.
            try? await Task.sleep(for: .seconds(3600))
        }
        return cachedImage(request)
    }
}

extension EnvironmentValues {
    /// Where cells get their photos. The app sets a `DiskImageLoader` for its store; previews keep
    /// this sample one.
    @Entry var imageLoader: any ImageLoading = MockImageLoader()
}
