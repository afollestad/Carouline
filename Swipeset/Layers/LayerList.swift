//
//  LayerList.swift
//  Swipeset
//

import SwiftUI

/// The layers sheet's first page: a slide's layers, top first, to restack and delete, over its
/// layout, which stays at the bottom.
struct LayerList: View {
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    let session: LayerSession
    let actions: LayerActions
    let onAdd: (LayerKind) -> Void
    let close: () -> Void

    var body: some View {
        // Read from the library each time, so the rows' offsets always match what's shown.
        let layers = Array((slide?.layers ?? []).reversed())
        List {
            Section {
                if layers.isEmpty {
                    emptyState
                }
                ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                    row(layer, isTop: index == 0, isBottom: index == layers.count - 1)
                }
                .onMove { offsets, destination in
                    let order = LayerOrder.reordered(topFirst: layers.map(\.id), fromOffsets: offsets, toOffset: destination)
                    withAnimation {
                        library.reorderLayers(in: slideID, of: projectID, to: order)
                    }
                }
                .onDelete { offsets in
                    withAnimation {
                        for layerID in LayerOrder.ids(topFirst: layers.map(\.id), at: offsets) {
                            library.deleteLayer(at: address(of: layerID))
                        }
                    }
                }
            }
            // Its own section, so no drag can drop a layer beneath it.
            Section {
                layoutRow
                // A share of the most, which reads plainer than a share of the slide's width.
                PercentSlider(title: "Blur", value: blur, maximum: 1, fractionLength: 0, showsTitle: true) {
                    session.endSlideBlur(to: library, projectID: projectID)
                }
            }
        }
        .layerPage("Layers", close: close)
        // VoiceOver's adjustments never end a drag, so what they leave is saved as the list goes.
        .onDisappear {
            session.endSlideBlur(to: library, projectID: projectID)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Layer", systemImage: "plus") {
                    session.sheetPath.append(.add)
                }
                // As the close button is, which the accent loses its contrast beside on the glass.
                .tint(Color.primary)
            }
        }
    }

    private var slide: Slide? {
        library.project(projectID)?.slides.first { $0.id == slideID }
    }

    /// The slide's blur, as a share of the most, dragged live on the slide and saved once let go.
    private var blur: Binding<Double> {
        Binding {
            (session.blurringSlideID == slideID ? session.slideBlur : slide?.blur ?? 0) / Slide.maximumBlur
        } set: { share in
            if session.blurringSlideID != slideID {
                session.beginSlideBlur(slide?.blur ?? 0, on: slideID)
            }
            session.slideBlur = share * Slide.maximumBlur
        }
    }

    private func address(of layerID: UUID) -> LayerAddress {
        LayerAddress(projectID: projectID, slideID: slideID, layerID: layerID)
    }

    /// With no layers yet, the kinds to add, a tap away.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This slide has no layers yet.")
                .font(.subheadline)
            LayerKindTiles(isAddingImage: library.importingLayers[slideID] != nil, onAdd: onAdd)
        }
        .listRowBackground(Color.clear)
    }

    private func row(_ layer: Layer, isTop: Bool, isBottom: Bool) -> some View {
        let address = address(of: layer.id)
        return Button {
            actions.select(address)
            session.sheetPath.append(.editor(for: layer))
        } label: {
            HStack(spacing: 12) {
                LayerPreview(layer: layer, projectID: projectID)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(of: layer))
                        .lineLimit(1)
                    // Primary, since gray washes out on the glass over a bright slide.
                    Text(detail(of: layer))
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Selects the layer and edits it")
        .accessibilityActions {
            if !isTop {
                Button("Bring Forward") { actions.move(address, 1) }
            }
            if !isBottom {
                Button("Send Backward") { actions.move(address, -1) }
            }
        }
    }

    private func title(of layer: Layer) -> String {
        switch layer.content {
        case .text(let text): text.text.split(separator: "\n").first.map(String.init) ?? text.text
        case .image: LayerKind.image.name
        }
    }

    private func detail(of layer: Layer) -> String {
        switch layer.content {
        case .text(let text): text.font.name
        case .image(let picture):
            switch (picture.borderWidth > 0, picture.blur > 0) {
            case (true, true): "Border, blurred"
            case (true, false): "Border"
            case (false, true): "No border, blurred"
            case (false, false): "No border"
            }
        }
    }

    /// The layout, beneath every layer, which can't move or go.
    private var layoutRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.fill.quaternary)
                .overlay {
                    // Primary, as the layers' previews above it draw, so it shows on the glass.
                    Image(systemName: "rectangle.split.2x2")
                        .foregroundStyle(Color.primary)
                }
                .frame(width: LayerPreview.side, height: LayerPreview.side)
            VStack(alignment: .leading, spacing: 2) {
                Text("Layout")
                Text(slide?.layout.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
            }
            Spacer(minLength: 0)
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Layout, \(slide?.layout.name ?? ""), beneath every layer")
    }
}

#Preview {
    let project = SampleProjects.all[0]
    let slide = project.slides[2]
    NavigationStack {
        LayerList(
            library: ProjectLibrary(store: MockProjectStore(), projects: [project]),
            projectID: project.id,
            slideID: slide.id,
            session: LayerSession(),
            actions: .preview,
            onAdd: { _ in },
            close: {}
        )
    }
    .tint(.accentColor)
}
