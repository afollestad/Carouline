//
//  PhotoLibrarySource.swift
//  Swipeset
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
}

/// A library of drawn photos, for previews and tests.
nonisolated struct MockPhotoLibrary: PhotoLibrarySource {
    var canReadWithoutAsking = true
    /// What the user answers when asked.
    var grantsAccess = true
    /// Identifiers of assets that still exist.
    var assets: Set<String> = []

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
}

extension EnvironmentValues {
    /// Where missing photos are restored from.
    @Entry var photoLibrary: any PhotoLibrarySource = PhotoKitLibrary()
}
