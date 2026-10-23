//
//  TrayThumbnail.swift
//  Carouline
//

import SwiftUI

/// One photo in the tray: a tap puts it on a slide, or takes it off once it's on one. Held, it shows
/// large over the tray, and lifted there, it shows what else it can do.
struct TrayThumbnail: View {
    let photo: TrayPhoto
    let projectID: UUID
    /// The cells holding it, which a badge marks, with how many once that's more than one.
    let places: [TrayPhotoPlace]
    /// Where it sits in the tray, as in "photo 3 of 12", for VoiceOver.
    let position: String
    /// The slides it's on, as "Slides 2 and 5", for its preview, or nil when it's on none.
    let usedOn: String?
    let actions: TrayActions
    @State private var isMissing = false
    /// Whether it's asking which of its places to take it off.
    @State private var isChoosingPlace = false
    /// The places it asked about, kept as they were, so its choices don't drop out as the popover
    /// fades with the photo already taken off them.
    @State private var choosingPlaces: [TrayPhotoPlace] = []
    /// What a choice in its actions' popover does once the popover has gone.
    @State private var afterMenu: (() -> Void)?
    @Environment(TrayPress.self) private var press: TrayPress?
    @Environment(\.shownPopovers) private var popovers
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Tall enough to make out what's in a photo, with room above and below in the bar's glass.
    static let height: CGFloat = 44

    var body: some View {
        Button {
            if isMissing {
                actions.restore(photo.id)
            } else if places.isEmpty {
                actions.place(photo.id)
            } else {
                removeFromSlides()
            }
        } label: {
            PhotoThumbnail(image: photo.image, projectID: projectID, height: Self.height, isMissing: $isMissing)
                .overlay(alignment: .topTrailing) {
                    if !places.isEmpty {
                        UsedBadge(count: places.count)
                    }
                }
        }
        .buttonStyle(TrayThumbnailStyle())
        .hoverEffect(.lift)
        // From a view of its own, since the button presents the question about removing it.
        .background {
            Color.clear
                .popover(isPresented: isShowingMenu) {
                    CaptionPopover(groups: menuGroups, header: { menuHeader }, onGone: menuGone)
                }
        }
        .confirmationPopover("Remove from Which Slide?", isPresented: $isChoosingPlace) {
            ForEach(choosingPlaces, id: \.address) { place in
                Button(place.name, role: .destructive) {
                    actions.removeFromSlides(photo.id, [place])
                }
            }
            Button("Remove from All", role: .destructive) {
                actions.removeFromSlides(photo.id, choosingPlaces)
            }
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityActions {
            ForEach(choices.flatMap { $0 }) { choice in
                Button(choice.title, systemImage: choice.systemImage, role: choice.isDestructive ? .destructive : nil, action: choice.action)
            }
        }
        .task(id: isMissing) {
            if isMissing {
                actions.restoreQuietly(photo.id)
            }
        }
        .onChange(of: isMissing, initial: true) { _, isMissing in
            press?.setMissing(isMissing, for: photo.id)
        }
        // Its actions go with it, as when another window takes it out of the tray.
        .onDisappear {
            if press?.menuPhotoID == photo.id {
                press?.menuPhotoID = nil
            }
        }
    }

    /// What it can do, in groups a line apart in its popover: put it somewhere, or bring it back,
    /// then take it off the slides or the tray.
    private var choices: [[CaptionChoice]] {
        var placing: [CaptionChoice] = []
        if isMissing {
            if photo.image.assetIdentifier != nil {
                placing.append(CaptionChoice(title: "Restore from Photos", systemImage: "arrow.clockwise") {
                    actions.restore(photo.id)
                })
            }
        } else {
            if let roomInFront = actions.roomInFront {
                placing.append(CaptionChoice(title: "Add to \(roomInFront)", systemImage: "plus.square.on.square") {
                    actions.place(photo.id)
                })
            }
            placing.append(CaptionChoice(title: "Choose a Cell…", systemImage: "hand.tap") {
                actions.hold(photo.id)
            })
            placing.append(CaptionChoice(title: "Start a Slide…", systemImage: "plus.rectangle.on.rectangle") {
                actions.startSlide(photo.id)
            })
        }
        var removing: [CaptionChoice] = []
        if !places.isEmpty {
            let title = places.count == 1 ? "Remove from \(places[0].name)" : "Remove from a Slide…"
            removing.append(CaptionChoice(title: title, systemImage: "minus.square", isDestructive: true, action: removeFromSlides))
        }
        removing.append(CaptionChoice(title: "Remove from Tray", systemImage: "trash", isDestructive: true) {
            actions.remove(photo.id)
        })
        return [placing, removing].filter { !$0.isEmpty }
    }

    /// `choices`, each done once the popover has gone.
    private var menuGroups: [[CaptionChoice]] {
        choices.map { group in
            group.map { choice in
                CaptionChoice(title: choice.title, systemImage: choice.systemImage, isDestructive: choice.isDestructive) {
                    chooseInMenu(choice.action)
                }
            }
        }
    }

    /// The photo large atop its actions, as a long press showed it before, where there's room for
    /// it: not at a compact height, as a phone's in landscape.
    @ViewBuilder
    private var menuHeader: some View {
        if verticalSizeClass != .compact {
            TrayPhotoPreview(photo: photo, projectID: projectID, usedOn: usedOn)
            Divider()
                .padding(.vertical, 4)
        }
    }

    /// Whether its actions are open, as lifting a finger held on it in the tray opens them.
    private var isShowingMenu: Binding<Bool> {
        Binding {
            press?.menuPhotoID == photo.id
        } set: { isShown in
            if !isShown, press?.menuPhotoID == photo.id {
                press?.menuPhotoID = nil
            }
        }
    }

    /// Closes its actions and does `action` once they've gone, since a sheet, a popover or a
    /// question asked for as they go never shows.
    private func chooseInMenu(_ action: @escaping () -> Void) {
        afterMenu = action
        // At once rather than animated, since the choice waits for the popover to go.
        var closing = Transaction()
        closing.disablesAnimations = true
        withTransaction(closing) {
            press?.menuPhotoID = nil
        }
    }

    private func menuGone() {
        let action = afterMenu
        afterMenu = nil
        action?()
    }

    /// Takes it off its one place, or asks which to take it off when there are several, once any
    /// popover still closing has gone, which would cancel the question.
    private func removeFromSlides() {
        if places.count > 1 {
            choosingPlaces = places
            popovers.whenGone { isChoosingPlace = true }
        } else {
            actions.removeFromSlides(photo.id, places)
        }
    }

    private var label: String {
        let shape = Orientation(of: photo.image.pixelSize).name
        if isMissing {
            return "\(position.capitalizingFirstLetter), unavailable"
        }
        return "\(position.capitalizingFirstLetter), \(shape)\(usedText)"
    }

    private var usedText: String {
        switch places.count {
        case 0: ""
        case 1: ", on a slide"
        case let count: ", in \(count) places on slides"
        }
    }

    private var hint: String {
        if isMissing {
            photo.image.assetIdentifier == nil ? "" : "Restores the photo from your library"
        } else if places.count == 1 {
            "Removes the photo from \(places[0].spokenName)"
        } else if places.count > 1 {
            "Asks which slide to remove the photo from"
        } else {
            actions.placeHint
        }
    }
}

/// A thumbnail tapped through a tap gesture rather than a button's own tracking of the finger, which
/// carries on under a finger held on the tray, so lifting it would also tap the photo it landed on.
/// The tray's press cancels the tap gesture as it begins.
private struct TrayThumbnailStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(.rect)
            .onTapGesture(perform: configuration.trigger)
    }
}

/// A check on solid accent in a thumbnail's corner, marking a photo that's on a slide, or how many
/// cells hold it once that's more than one. White on the accent, which a faint tint would wash out
/// on the glass.
private struct UsedBadge: View {
    let count: Int

    var body: some View {
        Group {
            if count > 1 {
                Text(count, format: .number)
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    // Clear of the capsule's ends past one digit; one stays a circle.
                    .padding(.horizontal, count > 9 ? 4 : 0)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(minWidth: 16, minHeight: 16, maxHeight: 16)
        .background(Color.accentColor, in: .capsule)
        .padding(3)
        .accessibilityHidden(true)
    }
}

/// How a photo's shape reads.
nonisolated enum Orientation {
    case portrait
    case landscape
    case square
    /// Twice as wide as it's high or more, as a panorama's photo is.
    case wide

    init(of size: CGSize) {
        let aspect = size.height > 0 ? size.width / size.height : 1
        self = if aspect >= 2 {
            .wide
        } else if aspect > 1.05 {
            .landscape
        } else if aspect < 0.95 {
            .portrait
        } else {
            .square
        }
    }

    var name: String {
        switch self {
        case .portrait: "portrait"
        case .landscape: "landscape"
        case .square: "square"
        case .wide: "panoramic"
        }
    }
}

#Preview {
    let projectID = UUID()
    let places = (1...3).map { index in
        TrayPhotoPlace(
            address: CellAddress(projectID: projectID, slideID: UUID(), index: 0),
            slideIndex: index,
            numbers: (index + 1)...(index + 1),
            photoNumber: nil
        )
    }
    HStack {
        TrayThumbnail(
            photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 1365)),
            projectID: projectID,
            places: Array(places.prefix(1)),
            position: "photo 1 of 3",
            usedOn: "Slide 2",
            actions: .preview
        )
        TrayThumbnail(
            photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 2048, pixelHeight: 2048)),
            projectID: projectID,
            places: places,
            position: "photo 2 of 3",
            usedOn: "Slides 2, 3, and 4",
            actions: .preview
        )
        TrayThumbnail(
            photo: TrayPhoto(image: PlacedImage(assetIdentifier: nil, pixelWidth: 1536, pixelHeight: 2048)),
            projectID: projectID,
            places: [],
            position: "photo 3 of 3",
            usedOn: nil,
            actions: .preview
        )
    }
    .padding()
}
