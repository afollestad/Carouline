//
//  TrayPress.swift
//  Carouline
//

import SwiftUI

/// Where the tray's photos sit along its scroll view, as its stack lays them out, so a press finds
/// the photo under a finger, and where it shows, without waiting for the photos to measure
/// themselves, which a lazy stack does only for those in view.
struct TrayLayout: Equatable {
    /// A photo and where it starts and ends along the stack.
    struct Slot: Equatable {
        let photoID: UUID
        let minX: CGFloat
        let maxX: CGFloat
    }

    /// In from the scroll view's ends, past the glass's rounded ends.
    static let inset: CGFloat = 14
    static let spacing: CGFloat = 8

    let slots: [Slot]
    /// The whole stack's width, its insets included.
    let contentWidth: CGFloat

    /// `photos` at their thumbnails' widths, then `importingCount` places held for photos on their
    /// way in.
    init(photos: [TrayPhoto], importingCount: Int) {
        var slots: [Slot] = []
        var x = Self.inset
        for photo in photos {
            let width = PhotoThumbnail.width(for: photo.image.pixelSize, height: TrayThumbnail.height)
            slots.append(Slot(photoID: photo.id, minX: x, maxX: x + width))
            x += width + Self.spacing
        }
        x += CGFloat(importingCount) * (TrayThumbnail.height + Self.spacing)
        self.slots = slots
        contentWidth = photos.count + importingCount == 0 ? 2 * Self.inset : x - Self.spacing + Self.inset
    }

    /// The photo under `x` along the stack, or else the nearest, so a finger between two, past
    /// either end or over a place held for a photo on its way in still finds one.
    func photo(atX x: CGFloat) -> Slot? {
        slots.min { Self.distance(from: x, to: $0) < Self.distance(from: x, to: $1) }
    }

    private static func distance(from x: CGFloat, to slot: Slot) -> CGFloat {
        max(slot.minX - x, x - slot.maxX, 0)
    }
}

/// A tray photo held down: magnified while the finger runs along the tray, which scrolls by itself
/// at either end, and carried once the finger rises off it, to land in the cell it's let go over.
/// Lifted in the tray, it opens the photo's actions. Shared by the tray the press starts on, the
/// cards a photo is carried over and the overlay that draws it, through the environment.
@Observable
final class TrayPress {
    enum Phase {
        case scrubbing
        case carrying
    }

    /// What a press ends in.
    enum Outcome: Equatable {
        /// Lifted in the tray: the photo's actions.
        case menu(UUID)
        /// Let go over a cell.
        case drop(UUID, CellAddress)
    }

    /// A slide a photo can be carried over, where its card is on screen.
    struct Card {
        let frame: SlideFrame
        let slide: Slide
        let projectID: UUID
        /// The cells with a photo on its way in, which take none.
        let importing: Set<Int>
    }

    /// How far above the tray a finger rises to carry the photo, rather than look along the tray:
    /// past where a thumb strays as it slides along.
    static let carryHeight: CGFloat = 24

    /// The photo magnified or carried, or nil while none is held.
    private(set) var photoID: UUID?
    private(set) var phase = Phase.scrubbing
    /// The finger, in global coordinates.
    private(set) var location: CGPoint?
    /// The magnified photo's thumbnail, in global coordinates, where the tray lays it out and has
    /// scrolled it to.
    private(set) var anchor: CGRect?
    /// The cell a carried photo would land in.
    private(set) var target: CellAddress?
    /// The slide a carried photo is over, which comes forward once it rests there.
    private(set) var hoverSlideID: UUID?
    /// Whether the finger is at an end of the tray it can still scroll toward.
    private(set) var isAtEdge = false
    /// The photo whose actions are open.
    var menuPhotoID: UUID?

    @ObservationIgnored private var layout = TrayLayout(photos: [], importingCount: 0)
    /// The tray's scroll view, in global coordinates.
    @ObservationIgnored private var capsule: CGRect = .zero
    /// How far the tray is scrolled, and how far it scrolls, as its scroll view reports them.
    @ObservationIgnored private var offset: CGFloat = 0
    @ObservationIgnored private var maxOffset: CGFloat = 0
    /// Photos whose copies turned out unreadable, which can't land in a cell.
    @ObservationIgnored private var missing: Set<UUID> = []
    @ObservationIgnored private var cards: [UUID: Card] = [:]
    /// Where the strip stops showing slides on its trailing side, as iPhone Duo's column of bar
    /// buttons cuts it off, or nil where nothing does.
    @ObservationIgnored private var stripTrailingEdge: CGFloat?

    init() {}

    /// Held on `photoID` already, as a snapshot or a debug launch shows, with no finger to find it.
    init(scrubbing photoID: UUID) {
        magnify(photoID)
    }

    /// Carried with the finger at `location`, as a snapshot shows.
    init(carrying photoID: UUID, at location: CGPoint) {
        self.photoID = photoID
        phase = .carrying
        self.location = location
    }

    /// Starts a press with the finger at `location`, on the photo under it.
    func begin(at location: CGPoint) {
        reset()
        self.location = location
        magnify(layout.photo(atX: contentX(location.x))?.photoID)
        updateEdge()
    }

    /// Follows the finger to `location`: along the tray to the photo under it, up off the tray
    /// carrying the photo, and over the cells it would land in.
    func move(to location: CGPoint) {
        guard let photoID else {
            return
        }
        update(\.location, to: location)
        switch phase {
        case .scrubbing where location.y < capsule.minY - Self.carryHeight && !missing.contains(photoID):
            phase = .carrying
            retarget()
        case .scrubbing:
            magnify(layout.photo(atX: contentX(location.x))?.photoID)
        case .carrying where location.y >= capsule.minY:
            phase = .scrubbing
            retarget()
            magnify(layout.photo(atX: contentX(location.x))?.photoID)
        case .carrying:
            retarget()
        }
        updateEdge()
    }

    /// Ends the press as the finger lifts: in the photo's actions, lifted in the tray, or in the
    /// cell a carried photo is let go over, if any.
    func end() -> Outcome? {
        defer {
            reset()
        }
        guard let photoID else {
            return nil
        }
        return switch phase {
        case .scrubbing: .menu(photoID)
        case .carrying: target.map { .drop(photoID, $0) }
        }
    }

    /// Ends the press with nothing done, as when the system calls it off.
    func cancel() {
        reset()
    }

    /// Holds `photoID` magnified with no finger, as a debug launch does.
    func magnify(_ photoID: UUID?) {
        update(\.photoID, to: photoID)
        updateAnchor()
    }

    /// The photo under a pointer at `location`, as a secondary click finds it.
    func photo(at location: CGPoint) -> UUID? {
        layout.photo(atX: contentX(location.x))?.photoID
    }

    /// How fast the tray scrolls itself, in points a second, for a finger at either end, as the
    /// strip scrolls along a panorama for a layer held at its edge. Not while carrying, when the
    /// finger is over the slides.
    var edgeVelocity: CGFloat {
        guard photoID != nil, phase == .scrubbing, let location else {
            return 0
        }
        return EdgeScroll.velocity(at: location.x - capsule.minX, across: capsule.width)
    }

    /// Scrolls the tray on for `seconds` toward the end the finger is at, and finds the photo
    /// under it there, returning the offset to scroll to, or nil when it goes no further.
    func scrolled(by seconds: TimeInterval) -> CGFloat? {
        let next = min(max(offset + edgeVelocity * seconds, 0), furthestOffset)
        guard next != offset else {
            updateEdge()
            return nil
        }
        // Ahead of the scroll's report, so the next frame's builds on it.
        offset = next
        trayMoved()
        updateEdge()
        return next
    }

    func setLayout(_ layout: TrayLayout) {
        self.layout = layout
        trayMoved()
    }

    /// Where the tray's scroll view is on screen.
    func setCapsule(_ frame: CGRect) {
        capsule = frame
        trayMoved()
    }

    /// How far the tray is scrolled, and how far it scrolls, as its scroll view reports them.
    func trayScrolled(to offset: CGFloat, maxOffset: CGFloat) {
        self.offset = offset
        self.maxOffset = maxOffset
        trayMoved()
        updateEdge()
    }

    func setMissing(_ isMissing: Bool, for photoID: UUID) {
        if isMissing {
            missing.insert(photoID)
        } else {
            missing.remove(photoID)
        }
    }

    /// Where slide `slideID`'s card is, or nil once it's out of view, which retargets a carried
    /// photo, as the strip bringing a slide forward moves the cards under a still finger.
    func setCard(_ card: Card?, for slideID: UUID) {
        cards[slideID] = card
        retarget()
    }

    func setStripTrailingEdge(_ edge: CGFloat?) {
        stripTrailingEdge = edge
        retarget()
    }

    /// Where along the tray's stack a point on screen at `x` is.
    private func contentX(_ x: CGFloat) -> CGFloat {
        x - capsule.minX + offset
    }

    /// The furthest the tray scrolls: its stack past its scroll view, or less should the scroll view
    /// report less, as a lazy stack can until it has measured its photos.
    private var furthestOffset: CGFloat {
        max(0, min(layout.contentWidth - capsule.width, maxOffset))
    }

    /// Finds the photo under a still finger again, and where its thumbnail is now, once the tray
    /// moves under it.
    private func trayMoved() {
        if phase == .scrubbing, photoID != nil, let location {
            magnify(layout.photo(atX: contentX(location.x))?.photoID)
        } else {
            updateAnchor()
        }
    }

    private func updateAnchor() {
        let slot = photoID.flatMap { photoID in layout.slots.first { $0.photoID == photoID } }
        let anchor = slot.flatMap { slot in
            capsule.width > 0
                ? CGRect(x: capsule.minX + slot.minX - offset, y: capsule.minY, width: slot.maxX - slot.minX, height: capsule.height)
                : nil
        }
        update(\.anchor, to: anchor)
    }

    private func updateEdge() {
        let velocity = edgeVelocity
        update(\.isAtEdge, to: velocity < 0 ? offset > 0 : velocity > 0 && offset < furthestOffset)
    }

    /// The cell under a carried photo, and its slide, from the cards in view, leaving out a cell
    /// with a photo on its way in, and any cut off past the strip's trailing edge.
    private func retarget() {
        guard phase == .carrying, let location, stripTrailingEdge.map({ location.x < $0 }) ?? true,
              let card = cards.values.first(where: { $0.frame.frame.contains(location) }) else {
            update(\.target, to: nil)
            update(\.hoverSlideID, to: nil)
            return
        }
        let canvas = card.frame.canvas(of: card.slide)
        let cell = SelectionHit.cell(at: card.frame.canvasPoint(location), of: card.slide, style: card.slide.style, on: canvas)
        let target = cell.flatMap { card.importing.contains($0) ? nil : CellAddress(projectID: card.projectID, slideID: card.slide.id, index: $0) }
        update(\.hoverSlideID, to: card.slide.id)
        update(\.target, to: target)
    }

    private func reset() {
        update(\.photoID, to: nil)
        update(\.phase, to: .scrubbing)
        update(\.location, to: nil)
        update(\.anchor, to: nil)
        update(\.target, to: nil)
        update(\.hoverSlideID, to: nil)
        update(\.isAtEdge, to: false)
        cards = [:]
    }

    /// Sets an observed value only when it changes, so those drawing from it redraw no more often.
    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<TrayPress, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}
