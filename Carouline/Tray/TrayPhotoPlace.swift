//
//  TrayPhotoPlace.swift
//  Carouline
//

import Foundation

/// A cell holding a tray photo, as the tray names it.
nonisolated struct TrayPhotoPlace: Hashable, Sendable {
    let address: CellAddress
    let slideIndex: Int
    /// The carousel numbers of the cell's slide.
    let numbers: ClosedRange<Int>
    /// The cell's number on its slide, when the slide holds the photo more than once, so its
    /// name alone wouldn't say which.
    let photoNumber: Int?
}

extension TrayPhotoPlace {
    /// "Slide 2", a panorama's "Slides 3–4", or "Slide 2, Photo 1" on a slide holding the photo
    /// more than once.
    var name: String {
        photoNumber.map { "\(numbers.slidesName), Photo \($0)" } ?? numbers.slidesName
    }

    /// `name` as VoiceOver should read it.
    var spokenName: String {
        photoNumber.map { "\(numbers.spokenSlidesName), photo \($0)" } ?? numbers.spokenSlidesName
    }
}

nonisolated extension [TrayPhotoPlace] {
    /// The slides these places are on, by index, each once, in order.
    var slideIndexes: [Int] {
        reduce(into: []) { indexes, place in
            if indexes.last != place.slideIndex {
                indexes.append(place.slideIndex)
            }
        }
    }
}
