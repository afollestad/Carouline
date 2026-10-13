//
//  LayerDraftTests.swift
//  SwipesetTests
//

import Foundation
import SwiftUI
import Testing
@testable import Swipeset

/// The layer editor's drafts, and how the screen's layer actions open the layers sheet.
@MainActor
struct LayerDraftTests {
    private let store: CountingStore
    private let library: ProjectLibrary
    private let projectID: UUID
    private let slideID: UUID

    init() throws {
        store = CountingStore()
        library = ProjectLibrary(store: store, projects: [])
        projectID = library.createProject(aspectRatio: .portrait).id
        slideID = try #require(library.addSlide(.single, to: projectID))
    }

    private func address(_ layer: Layer) -> LayerAddress {
        LayerAddress(projectID: projectID, slideID: slideID, layerID: layer.id)
    }

    private func saved(_ layer: Layer) -> Layer? {
        library.layer(at: address(layer))
    }

    private func text(_ string: String) -> Layer {
        Layer(content: .text(TextLayer(text: string)))
    }

    private func actions(session: LayerSession, presenter: Binding<PresentationQueue<ProjectPresentation>>? = nil) -> LayerActions {
        ProjectLayerActions(
            library: library,
            projectID: projectID,
            session: session,
            presenter: presenter ?? .constant(PresentationQueue()),
            dynamicTypeSize: .large,
            select: { session.selection = $0 }
        )
        .actions
    }

    @Test func savesNewText() {
        let session = LayerSession()
        var layer = text("")
        session.beginDraft(of: layer, on: slideID, isNew: true)

        layer.content = .text(TextLayer(text: "Day one"))
        session.draft = layer
        session.saveDraft(to: library, projectID: projectID)

        #expect(saved(layer)?.content == layer.content)
        #expect(session.draft == nil)
        #expect(!session.isDraftNew)
    }

    /// New text left blank never reaches the library.
    @Test func dropsNewTextLeftBlank() {
        let session = LayerSession()
        let layer = text(" ")
        session.beginDraft(of: layer, on: slideID, isNew: true)

        session.saveDraft(to: library, projectID: projectID)

        #expect(saved(layer) == nil)
    }

    @Test func blankingSavedTextDeletesItsLayer() {
        let session = LayerSession()
        var layer = text("Day one")
        library.saveLayer(layer, in: slideID, of: projectID)
        session.beginDraft(of: layer, on: slideID)

        layer.content = .text(TextLayer(text: ""))
        session.draft = layer
        session.saveDraft(to: library, projectID: projectID)

        #expect(saved(layer) == nil)
    }

    /// A draft takes its content onto the layer as it is now, so a move made while the editor was
    /// open stays.
    @Test func keepsAMoveMadeWhileEditing() {
        let session = LayerSession()
        var layer = text("Day one")
        library.saveLayer(layer, in: slideID, of: projectID)
        session.beginDraft(of: layer, on: slideID)
        let moved = LayerPlacement(centerX: 0.2, centerY: 0.8)
        library.setPlacement(moved, at: address(layer))

        layer.content = .text(TextLayer(text: "Day two"))
        session.draft = layer
        session.saveDraft(to: library, projectID: projectID)

        #expect(saved(layer)?.placement == moved)
        #expect(saved(layer)?.content == .text(TextLayer(text: "Day two")))
    }

    /// A layer deleted while its editor was open stays deleted.
    @Test func dropsTheDraftOfADeletedLayer() {
        let session = LayerSession()
        let layer = text("Day one")
        library.saveLayer(layer, in: slideID, of: projectID)
        session.beginDraft(of: layer, on: slideID)

        library.deleteLayer(at: address(layer))
        session.saveDraft(to: library, projectID: projectID)

        #expect(saved(layer) == nil)
    }

    @Test func dropsNewTextWhoseSlideIsGone() throws {
        let session = LayerSession()
        let layer = text("Day one")
        try #require(library.addSlide(.single, to: projectID) != nil)
        session.beginDraft(of: layer, on: slideID, isNew: true)

        library.deleteSlide(slideID, in: projectID)
        session.saveDraft(to: library, projectID: projectID)

        let slides = try #require(library.project(projectID)?.slides)
        #expect(slides.count == 1)
        #expect(slides.allSatisfy { $0.layers.isEmpty })
        #expect(session.draft == nil)
    }

    /// Leaving the app saves typing so far, and editing carries on with what's now saved.
    @Test func savesWithoutEndingAsTheAppLeaves() {
        let session = LayerSession()
        var layer = text("Day")
        session.beginDraft(of: layer, on: slideID, isNew: true)

        session.saveDraft(to: library, projectID: projectID, endingEdit: false)
        #expect(saved(layer)?.content == layer.content)
        #expect(session.draft != nil)
        layer.content = .text(TextLayer(text: "Day one"))
        session.draft = layer
        session.saveDraft(to: library, projectID: projectID)

        #expect(library.project(projectID)?.slides.first?.layers.count == 1)
        #expect(saved(layer)?.content == layer.content)
    }

    /// Text cleared as the app leaves may only be making way for new words, so it isn't saved, which
    /// would delete the layer, until editing ends.
    @Test func keepsClearedTextAsTheAppLeaves() {
        let session = LayerSession()
        var layer = text("Day one")
        library.saveLayer(layer, in: slideID, of: projectID)
        session.beginDraft(of: layer, on: slideID)

        layer.content = .text(TextLayer(text: ""))
        session.draft = layer
        session.saveDraft(to: library, projectID: projectID, endingEdit: false)

        #expect(saved(layer)?.content == .text(TextLayer(text: "Day one")))
        #expect(session.draft == layer)
    }

    /// Typing changes only the draft, which saves the project's JSON once, as the editor closes,
    /// though the sheet saves again as it goes too.
    @Test func typingSavesOnceWhenTheEditorCloses() async {
        let session = LayerSession()
        var layer = text("Day one")
        library.saveLayer(layer, in: slideID, of: projectID)
        await library.flush()
        let saves = await store.saves
        session.beginDraft(of: layer, on: slideID)

        for count in 1...20 {
            layer.content = .text(TextLayer(text: String(repeating: "a", count: count)))
            session.draft = layer
        }
        session.saveDraft(to: library, projectID: projectID)
        session.saveDraft(to: library, projectID: projectID)
        await library.flush()

        #expect(await store.saves == saves + 1)
    }

    /// A new layer isn't in the library yet, so moving it moves its draft.
    @Test func movesANewLayersDraft() {
        let session = LayerSession()
        let layer = text("Day one")
        session.beginDraft(of: layer, on: slideID, isNew: true)

        session.commitPlacement(LayerPlacement(centerX: 0.3, scale: 9), at: address(layer), to: library)

        #expect(session.draft?.placement == LayerPlacement(centerX: 0.3, scale: LayerPlacement.scales.upperBound))
        #expect(saved(layer) == nil)
    }

    @Test func opensTheSheetAtEachEntryPointsPage() {
        let session = LayerSession()
        var presenter = PresentationQueue<ProjectPresentation>()
        let layer = text("Day one")
        library.saveLayer(layer, in: slideID, of: projectID)
        let actions = actions(session: session, presenter: Binding { presenter } set: { presenter = $0 })

        actions.openSheet(slideID, [.add])
        #expect(session.sheetPath == [.add])
        #expect(presenter.current == .layers(slideID))
        actions.openSheet(slideID, [])
        #expect(session.sheetPath.isEmpty)
        actions.edit(address(layer))
        #expect(session.sheetPath == [.text(layer.id)])
        #expect(presenter.current == .layers(slideID))
    }

    /// New text has no place in the stack until it's saved, so moving it saves it first.
    @Test func movingNewTextSavesItFirst() {
        let session = LayerSession()
        let below = text("Lisbon")
        library.saveLayer(below, in: slideID, of: projectID)
        let layer = text("Day one")
        session.beginDraft(of: layer, on: slideID, isNew: true)

        actions(session: session).move(address(layer), -1)

        #expect(library.project(projectID)?.slides.first?.layers.map(\.id) == [layer.id, below.id])
        #expect(!session.isDraftNew)
        #expect(session.draftLayer(layer.id) != nil)
    }

    /// Only text has an editor yet.
    @Test func editsOnlyText() {
        let session = LayerSession()
        var presenter = PresentationQueue<ProjectPresentation>()
        let picture = Layer(content: .image(ImageLayer(image: PlacedImage(assetIdentifier: nil, pixelWidth: 10, pixelHeight: 10))))
        library.saveLayer(picture, in: slideID, of: projectID)

        actions(session: session, presenter: Binding { presenter } set: { presenter = $0 }).edit(address(picture))

        #expect(presenter.current == nil)
        #expect(session.sheetPath.isEmpty)
    }

    /// Deleting new text that's still only a draft drops it, and its sheet, rather than the library's.
    @Test func deletingNewTextDropsItsDraft() {
        let session = LayerSession()
        var presenter = PresentationQueue<ProjectPresentation>()
        presenter.present(.layers(slideID))
        let layer = text("Day one")
        session.beginDraft(of: layer, on: slideID, isNew: true)
        session.selection = address(layer)
        let actions = actions(session: session, presenter: Binding { presenter } set: { presenter = $0 })

        actions.delete(address(layer))
        session.saveDraft(to: library, projectID: projectID)

        #expect(session.selection == nil)
        #expect(presenter.current == nil)
        #expect(saved(layer) == nil)
    }
}
