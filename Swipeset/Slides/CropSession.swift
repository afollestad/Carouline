//
//  CropSession.swift
//  Swipeset
//

import CoreGraphics
import Observation

/// The photo being framed and its crop mid-gesture. Only the selected cell and the selection
/// bar read `liveCrop`, so a drag redraws them alone rather than every slide, and the project
/// saves once when the gesture ends.
@Observable
final class CropSession {
    var selection: CellAddress?
    /// The crop being dragged, pinched or slid to, before it's saved.
    var liveCrop: ImageCrop?
    /// The selected cell's size, which the zoom slider frames the photo in.
    var cellSize: CGSize = .zero

    init(selection: CellAddress? = nil) {
        self.selection = selection
    }
}
