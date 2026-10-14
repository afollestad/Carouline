//
//  PhotoLibrarySource.swift
//  Carouline
//

import Photos
import SwiftUI
import UIKit

/// Reads originals back from the photo library, to restore a copy that went missing.
nonisolated protocol PhotoLibrarySource: Sendable {
    /// Whether the library can be read without asking, as after the user allowed full or limited access.
    var canReadWithoutAsking: Bool { get }
    /// Asks for access if the user hasn't been asked, and returns whether reading is allowed.
    func requestReadAccess() async -> Bool
    /// The asset's photo, upright, no larger than `maxPixelSize` on its longer side, or nil when
    /// the asset is gone, or hidden from limited access.
    func image(for assetIdentifier: String, maxPixelSize: Int) async -> UIImage?
    /// The asset's photo as the picker gave it, with any edits, and with transparency where it
    /// has any, which a picture layer's copy keeps, turned as Photos shows it; or nil when the
    /// asset is gone, or hidden from limited access.
    func imageData(for assetIdentifier: String) async -> Data?
}

/// The device's photo library through PhotoKit.
nonisolated struct PhotoKitLibrary: PhotoLibrarySource {
    var canReadWithoutAsking: Bool {
        [.authorized, .limited].contains(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestReadAccess() async -> Bool {
        [.authorized, .limited].contains(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    func image(for assetIdentifier: String, maxPixelSize: Int) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        // High quality alone calls back once, never with a degraded image first, which the
        // continuation could only take once. The original may be in iCloud only.
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        // No larger than the original, which an exact resize would otherwise scale up to.
        let scale = min(1, Double(maxPixelSize) / Double(max(asset.pixelWidth, asset.pixelHeight, 1)))
        let size = CGSize(width: Double(asset.pixelWidth) * scale, height: Double(asset.pixelHeight) * scale)
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    /// Off the main actor, since turning a photo copies all of it.
    @concurrent
    func imageData(for assetIdentifier: String) async -> Data? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        // Once, with the original, which may be in iCloud only, as edited, as the picker gave it.
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.version = .current
        let (data, orientation) = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, orientation, _ in
                continuation.resume(returning: (data, orientation))
            }
        }
        return data.map { Self.turned($0, to: orientation) }
    }

    /// `data` marked with `orientation`, which Photos gives apart from it, for the rare photo whose
    /// own metadata says otherwise, rewriting its metadata alone. As it was when it can't be.
    static func turned(_ data: Data, to orientation: CGImagePropertyOrientation) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else {
            return data
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        guard properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1 != orientation.rawValue else {
            return data
        }
        let output = NSMutableData()
        let options = [kCGImageDestinationOrientation: orientation.rawValue] as CFDictionary
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil),
              CGImageDestinationCopyImageSource(destination, source, options, nil) else {
            return data
        }
        return output as Data
    }
}

/// A library of drawn photos, for previews and tests.
nonisolated struct MockPhotoLibrary: PhotoLibrarySource {
    var canReadWithoutAsking = true
    /// What the user answers when asked.
    var grantsAccess = true
    /// Identifiers of assets that still exist.
    var assets: Set<String> = []
    /// Those of them cut out of their backgrounds, stored as PNGs with transparency.
    var cutouts: Set<String> = []

    func requestReadAccess() async -> Bool {
        canReadWithoutAsking || grantsAccess
    }

    func image(for assetIdentifier: String, maxPixelSize: Int) async -> UIImage? {
        guard assets.contains(assetIdentifier),
              let image = SampleImages.image(for: UUID(), width: 1600, height: 1200, maxPixelSize: maxPixelSize) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    func imageData(for assetIdentifier: String) async -> Data? {
        guard assets.contains(assetIdentifier) else {
            return nil
        }
        if cutouts.contains(assetIdentifier) {
            return SampleImages.sticker(for: UUID(), width: 600, height: 600).flatMap { UIImage(cgImage: $0).pngData() }
        }
        return SampleImages.image(for: UUID(), width: 1600, height: 1200).flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.9) }
    }
}

extension EnvironmentValues {
    /// Where missing photos are restored from.
    @Entry var photoLibrary: any PhotoLibrarySource = PhotoKitLibrary()
}
