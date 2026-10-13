//
//  LayerOrder.swift
//  Swipeset
//

import SwiftUI

/// A slide's layers as the layer list shows them, top first, mapped to and from the slide's own
/// order, bottom to top.
nonisolated enum LayerOrder {
    /// The layers' IDs bottom to top, after the list moves the rows at `offsets` of its
    /// top-first `ids` to `destination`.
    static func reordered(topFirst ids: [UUID], fromOffsets offsets: IndexSet, toOffset destination: Int) -> [UUID] {
        var moved = ids
        moved.move(fromOffsets: offsets, toOffset: destination)
        return moved.reversed()
    }

    /// The IDs of the rows at `offsets` of the list's top-first `ids`, as a swipe deletes them.
    static func ids(topFirst ids: [UUID], at offsets: IndexSet) -> [UUID] {
        offsets.filter(ids.indices.contains).map { ids[$0] }
    }
}
