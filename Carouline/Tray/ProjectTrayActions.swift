//
//  ProjectTrayActions.swift
//  Carouline
//

import SwiftUI

/// The tray actions the project screen hands its tray, built from the state they share with it.
struct ProjectTrayActions {
    let library: ProjectLibrary
    let project: Project
    /// The slide in the middle of the strip, or nil while there's none, or the strip rests on the
    /// button after them.
    let frontSlide: Slide?
    /// Where missing photos are restored from.
    let photoLibrary: any PhotoLibrarySource
    @Binding var presenter: PresentationQueue<ProjectPresentation>
    /// Holds a photo for a cell to be tapped, as the screen does.
    let hold: (HeldPhoto) -> Void
    /// Opens the layout sheet for a new slide that takes a photo in its first cell.
    let startSlide: (HeldPhoto) -> Void
    /// Whether a missing photo, by its copy's ID, is yet to be restored quietly, noting that it
    /// now has been, so one whose original is gone isn't tried on every redraw.
    let restoresQuietly: (UUID) -> Bool

    var actions: TrayActions {
        let projectID = project.id
        return TrayActions(
            addPhotos: {
                presenter.present(.photoPicker(.tray(projectID: projectID)))
            },
            addDropped: { photos in
                Task {
                    await library.importToTray(photos, in: projectID)
                }
            },
            place: place,
            hold: { hold(held($0)) },
            drop: { photoID, address in
                Task {
                    await library.land(held(photoID), at: address)
                }
            },
            startSlide: { startSlide(held($0)) },
            remove: { photoID in
                withAnimation {
                    library.removeFromTray(photoID, in: projectID)
                }
            },
            removeFromSlides: { photoID, places in
                let removed = withAnimation {
                    library.removeTrayPhoto(photoID, fromCellsAt: places.map(\.address), in: projectID)
                }
                // Places gone some other way, as from another window, while the choice was open
                // leave nothing to announce.
                if removed > 0 {
                    let name = switch (places.count, removed) {
                    case (1, _): places[0].spokenName
                    case (_, 1): "1 place"
                    default: "\(removed) places"
                    }
                    AccessibilityNotification.Announcement("Removed from \(name)").post()
                }
            },
            restore: { photoID in
                Task {
                    await library.restoreTrayPhoto(photoID, in: projectID, from: photoLibrary, asking: true)
                }
            },
            restoreQuietly: { photoID in
                guard let imageID = library.trayPhoto(photoID, in: projectID)?.image.id, restoresQuietly(imageID) else {
                    return
                }
                Task {
                    await library.restoreTrayPhoto(photoID, in: projectID, from: photoLibrary, asking: false)
                }
            },
            roomInFront: emptyCellInFront == nil ? nil : frontSlideNumbers?.slidesName,
            placeHint: placeHint
        )
    }

    private func held(_ photoID: UUID) -> HeldPhoto {
        .tray(projectID: project.id, photoID: photoID)
    }

    /// Puts tray photo `photoID` in the front slide's next empty cell; with that full, holds it
    /// for a cell to be tapped, and with no slide in front, starts one with it.
    private func place(_ photoID: UUID) {
        guard frontSlide != nil else {
            startSlide(held(photoID))
            return
        }
        guard let cell = emptyCellInFront else {
            hold(held(photoID))
            return
        }
        Task {
            await library.land(held(photoID), at: cell)
        }
        if let frontSlideNumbers {
            AccessibilityNotification.Announcement("Added to \(frontSlideNumbers.spokenSlidesName)").post()
        }
    }

    private var placeHint: String {
        if frontSlide == nil {
            "Starts a new slide with the photo"
        } else if emptyCellInFront != nil, let frontSlideNumbers {
            "Adds the photo to \(frontSlideNumbers.spokenSlidesName)"
        } else {
            "Holds the photo for you to tap a cell or a picture"
        }
    }

    private var emptyCellInFront: CellAddress? {
        frontSlide.flatMap { library.emptyCell(in: $0.id, of: project.id) }
    }

    /// The front slide's carousel numbers.
    private var frontSlideNumbers: ClosedRange<Int>? {
        guard let frontSlide, let index = project.slides.firstIndex(where: { $0.id == frontSlide.id }) else {
            return nil
        }
        return project.slideNumbers[index]
    }
}
