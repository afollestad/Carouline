//
//  ItemProviderLoading.swift
//  Carouline
//

import CoreTransferable
import Foundation

/// Reads what a drop brings. A drop's item providers must be read before the drop ends, so each
/// read starts at once, and what it reads waits for whoever needs it.
nonisolated enum ItemProviderLoading {
    /// Starts reading `provider`'s `T`, and returns the wait for it.
    static func load<T: Transferable & Sendable>(_ type: T.Type, from provider: NSItemProvider) -> @Sendable () async throws -> T {
        let (stream, continuation) = AsyncThrowingStream<T, any Error>.makeStream()
        _ = provider.loadTransferable(type: type) { result in
            continuation.yield(with: result)
            continuation.finish()
        }
        return {
            for try await value in stream {
                return value
            }
            throw CocoaError(.fileReadUnknown)
        }
    }
}

extension IncomingPhoto {
    /// The photos `providers` bring from another app, as Photos does in Split View, each read at
    /// once. None comes with a library identifier, which another app's drop never gives.
    static func dropped(_ providers: [NSItemProvider]) -> [IncomingPhoto] {
        providers.map { provider in
            let photo = ItemProviderLoading.load(PickedPhoto.self, from: provider)
            return IncomingPhoto(assetIdentifier: nil) {
                .file(try await photo().url)
            }
        }
    }
}
