//
//  PhotoPickerHost.swift
//  Carouline
//

import PhotosUI
import SwiftUI

/// What the photo picker fills.
enum PickTarget: Hashable {
    /// A cell, and its slide's other empty cells when the pick takes several, up to `limit`.
    case cells(CellAddress, limit: Int)
    /// A project's tray, which takes as many as are picked.
    case tray(projectID: UUID)

    /// How many photos the pick can take, or nil for as many as are picked.
    var limit: Int? {
        switch self {
        case .cells(_, let limit): limit
        case .tray: nil
        }
    }
}

/// The photo picker the project screen opens, and what it does with the pick it hands over. A
/// tray's opens with the library photos already in the tray checked, so the picker shows the tray
/// as it is: checking more adds them, and unchecking one asks, through `removals`, whether to take
/// it out.
struct PhotoPickerHost: ViewModifier {
    let library: ProjectLibrary
    let removals: TrayRemovals
    /// The pick the screen has open, as its presenter reads and closes it.
    let presented: Binding<PickTarget?>
    /// What the pick in hand fills. Kept apart from `presented`, which the picker clears as it
    /// closes, possibly before it hands over the pick.
    @State private var target: PickTarget?
    @State private var pickedItems: [PhotosPickerItem] = []
    /// The library photos the picker opened with checked, by identifier: those in the tray.
    @State private var checkedOnOpening: [String] = []
    /// Whether the picker is up. Raised only once its selection holds the photos it opens with
    /// checked, which it reads as it opens.
    @State private var isPickerShown = false

    func body(content: Content) -> some View {
        content
            // The only presentation with no content to call `presentPending()` as it goes, which
            // it needn't, since it covers the screen and nothing can be asked for behind it.
            .photosPicker(
                isPresented: isPresented,
                selection: $pickedItems,
                maxSelectionCount: target?.limit,
                // Numbered in the order they're picked, which is the order they fill the cells, and
                // the tray.
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .current,
                photoLibrary: .shared()
            )
            .onChange(of: presented.wrappedValue) { _, presented in
                if let presented {
                    open(for: presented)
                } else {
                    isPickerShown = false
                }
            }
            .onChange(of: pickedItems) { _, items in
                apply(items)
            }
    }

    private var isPresented: Binding<Bool> {
        Binding {
            isPickerShown
        } set: { isShown in
            isPickerShown = isShown
            if !isShown {
                presented.wrappedValue = nil
            }
        }
    }

    /// Opens the picker for `target`, with the tray's library photos checked for a tray.
    private func open(for target: PickTarget) {
        self.target = target
        checkedOnOpening = switch target {
        case .cells: []
        case .tray(let projectID): library.project(projectID)?.tray.compactMap(\.image.assetIdentifier) ?? []
        }
        pickedItems = checkedOnOpening.map(PhotosPickerItem.init(itemIdentifier:))
        isPickerShown = true
    }

    /// Copies the photos checked since the picker opened into what it was opened for, keeping each
    /// one's library identifier so its copy can be restored from it, and asks about the tray's
    /// photos the pick left out.
    private func apply(_ items: [PhotosPickerItem]) {
        guard let target else {
            return
        }
        let wasChecked = Set(checkedOnOpening)
        let checked = Set(items.compactMap(\.itemIdentifier))
        let added = items.filter { item in item.itemIdentifier.map { !wasChecked.contains($0) } ?? true }
        let unchecked = wasChecked.subtracting(checked)
        // Nothing, as when the picker opens with the tray's photos checked.
        guard !added.isEmpty || !unchecked.isEmpty else {
            return
        }
        self.target = nil
        checkedOnOpening = []
        pickedItems = []
        let photos = added.map { item in
            IncomingPhoto(assetIdentifier: item.itemIdentifier) {
                try await item.loadTransferable(type: PickedPhoto.self).map { .file($0.url) }
            }
        }
        if case .tray(let projectID) = target {
            removals.ask(about: unchecked, in: projectID)
        }
        Task {
            switch target {
            case .cells(let address, _):
                await library.importPhotos(photos, into: address)
            case .tray(let projectID):
                await library.importToTray(photos, in: projectID)
            }
        }
    }
}
