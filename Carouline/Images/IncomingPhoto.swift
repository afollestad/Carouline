//
//  IncomingPhoto.swift
//  Carouline
//

import Foundation

/// A photo arriving from outside the project, as the picker or a drop hands one over. It's read
/// only once its copy is being made, so a slow load shows as importing too.
nonisolated struct IncomingPhoto: Sendable {
    /// The Photos asset it came from, which its copy can be restored from, or nil for one that
    /// isn't in the library.
    let assetIdentifier: String?
    /// Reads the photo, or returns nil when there's nothing to read, as a picker's item can.
    let load: @Sendable () async throws -> PhotoSource?
}
