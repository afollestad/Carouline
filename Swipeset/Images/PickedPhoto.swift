//
//  PickedPhoto.swift
//  Swipeset
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A photo from the picker, received as a file so a large original never has to fit in memory.
nonisolated struct PickedPhoto: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            // The received file goes when this returns, so it's copied somewhere the launch
            // sweep empties, in case the import never finishes.
            let folder = ProjectPaths.live.imports
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appending(path: "\(UUID().uuidString)-\(received.file.lastPathComponent)")
            try FileManager.default.copyItem(at: received.file, to: url)
            return PickedPhoto(url: url)
        }
    }
}
