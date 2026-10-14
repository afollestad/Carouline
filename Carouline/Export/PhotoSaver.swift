//
//  PhotoSaver.swift
//  Carouline
//

import Photos
import SwiftUI

/// Saves exported slides to the photo library.
nonisolated protocol PhotoSaving: Sendable {
    /// Saves `files` in order, asking to add to the library first if it hasn't been asked.
    func save(_ files: [URL]) async throws
}

enum PhotoSaveError: Error {
    /// The user doesn't allow adding to the photo library.
    case denied
}

/// Saves through PhotoKit, with access to add photos alone, which never reveals the library.
nonisolated struct PhotoKitSaver: PhotoSaving {
    func save(_ files: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.denied
        }
        // A second apart, ending now, so the library sorts them in the carousel's order.
        let start = Date.now.addingTimeInterval(-Double(files.count - 1))
        try await PHPhotoLibrary.shared().performChanges {
            for (index, file) in files.enumerated() {
                let request = PHAssetCreationRequest.forAsset()
                request.creationDate = start.addingTimeInterval(Double(index))
                request.addResource(with: .photo, fileURL: file, options: nil)
            }
        }
    }
}

/// Saves nothing, for previews and snapshots, failing when told to.
nonisolated struct MockPhotoSaver: PhotoSaving {
    var failure: PhotoSaveError?

    func save(_ files: [URL]) async throws {
        if let failure {
            throw failure
        }
    }
}

extension EnvironmentValues {
    @Entry var photoSaver: any PhotoSaving = PhotoKitSaver()
}
