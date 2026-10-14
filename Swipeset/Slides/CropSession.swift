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
    var selection: CellAddress? {
        // A gesture still running when another photo is selected frames nothing more, and the
        // next one begins from that photo's own crop.
        didSet {
            if selection != oldValue {
                gestureStart = nil
            }
        }
    }
    /// The crop being dragged, pinched or slid to, before it's saved.
    var liveCrop: ImageCrop?
    /// The selected cell's size, which gestures and the zoom slider frame the photo in.
    var cellSize: CGSize = .zero
    /// The crop when the current drag or pinch began, which the gesture's values build on.
    @ObservationIgnored private var gestureStart: ImageCrop?

    init(selection: CellAddress? = nil) {
        self.selection = selection
    }

    /// Frames `image` by a gesture's drag `translation` and its pinch's `magnification` about
    /// `anchor`, in the cell's coordinates. Both build on the crop the gesture began from, so the
    /// photo tracks the fingers exactly.
    func frame(_ image: PlacedImage, translation: CGSize?, magnification: CGFloat?, anchor: CGPoint) {
        // Until the cell has measured itself there's nothing to frame the photo in, and framing
        // it in no room would reset its crop.
        guard cellSize.width > 0, cellSize.height > 0 else {
            return
        }
        let start = gestureStart ?? liveCrop ?? image.crop
        gestureStart = start
        var crop = start
        if let magnification {
            crop = CropGeometry.zoomed(crop, by: magnification, about: anchor, imageSize: image.pixelSize, cellSize: cellSize)
        }
        if let translation {
            crop = CropGeometry.panned(crop, by: translation, imageSize: image.pixelSize, cellSize: cellSize)
        }
        liveCrop = crop
    }

    /// Carries the gesture on from the crop it's at, as the fingers change, so its next values
    /// build on that rather than the crop it began from, and zoom about where the fingers are now.
    func rebase() {
        gestureStart = nil
    }

    /// Drops the gesture and the crop it or the zoom slider left, unsaved, as when another photo
    /// replaces the one they framed, which they mustn't carry over to.
    func discardFraming() {
        liveCrop = nil
        gestureStart = nil
    }

    /// Ends the gesture, returning the crop it left for saving.
    func endFraming() -> ImageCrop? {
        defer {
            liveCrop = nil
            gestureStart = nil
        }
        return liveCrop
    }
}
