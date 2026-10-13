//
//  LayerList.swift
//  Swipeset
//

import SwiftUI

/// The layers sheet's first page: a slide's layers, top first, to restack and delete, over its
/// layout, which stays at the bottom, and the slide's style and blur beneath them. The style and
/// blur draw live on the slide as they're edited, and save once a slider is let go, a swatch is
/// picked, or the page goes.
struct LayerList: View {
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    let session: LayerSession
    let actions: LayerActions
    let onAdd: (LayerKind) -> Void
    let close: () -> Void

    @State private var editMode = EditMode.inactive

    private static let styleTitles = ["Spacing", "Border", "Blur"]

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
                styleSlider("Spacing", value: share(of: \.spacing, maximum: SlideStyle.maximumSpacing))
                styleSlider("Border", value: share(of: \.border, maximum: SlideStyle.maximumBorder))
                styleSlider("Blur", value: blur)
            }
            Section {
                ColorSwatches(title: "Background", color: background, onCommit: endStyling)
            }
            ApplyStyleSection(library: library, projectID: projectID, slideID: slideID, session: session)
        }
        .layerPage("Layers", close: close)
        // VoiceOver's adjustments never end a drag, and the color picker never says it's done, so
        // what they leave is saved as the list goes.
        .onDisappear(perform: endStyling)
        .toolbar {
            // Its reorder grips are the only sign that a row can be dragged. Hidden, not disabled, with
            // nothing to edit, since a disabled one all but vanishes on the glass.
            if !layers.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                        // Edit in primary, as the close button is, and Done's checkmark on solid accent.
                        .tint(editMode.isEditing ? Color.accentColor : Color.primary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Layer", systemImage: "plus") {
                    session.sheetPath.append(.add)
                }
                // As the close button is, which the accent loses its contrast beside on the glass.
                .tint(Color.primary)
            }
        }
        .environment(\.editMode, $editMode)
        // Deleting the last layer hides Done, which would leave the list stuck editing.
        .onChange(of: layers.isEmpty) { _, isEmpty in
            if isEmpty {
                editMode = .inactive
            }
        }
    }

    private var slide: Slide? {
        library.project(projectID)?.slides.first { $0.id == slideID }
    }

    /// The slide's style as it's shown: as edited, or else as saved.
    private var shownStyle: SlideStyle {
        session.stylingSlideID == slideID ? session.slideStyle : slide?.style ?? .standard
    }

    /// A share of the most, which reads plainer than a share of the slide's width.
    private func styleSlider(_ title: String, value: Binding<Double>) -> some View {
        PercentSlider(
            title: title,
            value: value,
            maximum: 1,
            fractionLength: 0,
            showsTitle: true,
            alignedTitles: Self.styleTitles,
            onCommit: endStyling
        )
    }

    /// `keyPath` of the slide's style, as a share of `maximum`.
    private func share(of keyPath: WritableKeyPath<SlideStyle, Double>, maximum: Double) -> Binding<Double> {
        Binding {
            shownStyle[keyPath: keyPath] / maximum
        } set: { share in
            if beginStyling() {
                session.slideStyle[keyPath: keyPath] = Self.wholePercent(share) * maximum
            }
        }
    }

    /// The slide's blur, as a share of the most.
    private var blur: Binding<Double> {
        Binding {
            (session.stylingSlideID == slideID ? session.slideBlur : slide?.blur ?? 0) / Slide.maximumBlur
        } set: { share in
            if beginStyling() {
                session.slideBlur = Self.wholePercent(share) * Slide.maximumBlur
            }
        }
    }

    private var background: Binding<RGBColor> {
        Binding {
            shownStyle.background
        } set: { color in
            if beginStyling() {
                session.slideStyle.background = color
            }
        }
    }

    /// `share` rounded to the percent the slider reads, so slides that read alike are alike.
    private static func wholePercent(_ share: Double) -> Double {
        (share * 100).rounded() / 100
    }

    /// Starts editing the slide's style and blur, unless it already is, first saving any other
    /// slide's. False once the slide's gone.
    private func beginStyling() -> Bool {
        guard let slide else {
            return false
        }
        if session.stylingSlideID != slideID {
            endStyling()
            session.beginStyling(slide)
        }
        return true
    }

    private func endStyling() {
        session.endStyling(to: library, projectID: projectID)
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
                // The reorder grip takes its place while editing.
                if !editMode.isEditing {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // A tap does nothing while editing, as in other lists. Not `disabled`, which grays the text
        // out on the glass.
        .allowsHitTesting(!editMode.isEditing)
        .modifier(LiftsWholeRow())
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

/// Gives every slide this one's style, once another slide's differs from the one shown. Apart
/// from the list, so only it redraws as the style is dragged.
private struct ApplyStyleSection: View {
    let library: ProjectLibrary
    let projectID: UUID
    let slideID: UUID
    let session: LayerSession
    @State private var isConfirming = false

    var body: some View {
        if let project = library.project(projectID), let slide = project.slides.first(where: { $0.id == slideID }) {
            // As shown, so a color the picker left unsaved can be given too.
            let style = session.stylingSlideID == slideID ? session.slideStyle : slide.style
            if !project.slides(besides: slideID, allHave: style) {
                Section {
                    Button {
                        isConfirming = true
                    } label: {
                        Label("Apply Style to All Slides", systemImage: "square.on.square")
                    }
                    .accessibilityHint("Gives every slide this slide's spacing, border and background")
                    // From the button, so on iPad it points there.
                    .confirmationDialog("Apply Style to All Slides?", isPresented: $isConfirming, titleVisibility: .visible) {
                        Button("Apply to All Slides", action: apply)
                    } message: {
                        Text("Every slide takes this slide's spacing, border and background.")
                    }
                    // Primary, the row's and the dialog's action alike, since the accent washes out
                    // on the glass.
                    .tint(Color.primary)
                }
            }
        }
    }

    /// Saves the style being edited first, which VoiceOver or the color picker may have left.
    private func apply() {
        session.endStyling(to: library, projectID: projectID)
        withAnimation {
            library.applyStyle(of: slideID, toAllIn: projectID)
        }
    }
}

/// Lifts a row to reorder whole and rounded. The list lifts it square, its corners filled over
/// the section's rounding, and a drag-preview shape the size of the content alone narrows the row
/// as it lifts and widens it with a jump once dropped. A dropped row keeps these corners for about
/// 0.8 s, until UIKit's set-down crossfade ends and hands the row back, which no API shortens.
private struct LiftsWholeRow: ViewModifier {
    /// The row's cell in the content's space, which takes in the edit mode's controls.
    @State private var rowBounds: CGRect?

    func body(content: Content) -> some View {
        content
            .background {
                RowBoundsReader { rowBounds = $0 }
            }
            .contentShape(.dragPreview, RowShape(rowBounds: rowBounds))
    }

    private struct RowShape: Shape {
        let rowBounds: CGRect?

        /// The inset grouped list's section corners, measured, since no API exposes them.
        private let cornerRadius: CGFloat = 26

        func path(in rect: CGRect) -> Path {
            Path(roundedRect: rowBounds ?? rect, cornerRadius: cornerRadius)
        }
    }
}

/// Reads the bounds of the list cell around it, in its own space. SwiftUI's geometry stops at a
/// row's content, which edit mode's controls sit outside of.
private struct RowBoundsReader: UIViewRepresentable {
    let onChange: (CGRect) -> Void

    func makeUIView(context: Context) -> ReaderView {
        ReaderView(onChange: onChange)
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: (CGRect) -> Void
        private var reported: CGRect?

        init(onChange: @escaping (CGRect) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // Its first layout can come before the row is in its cell.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        private func report() {
            var view = superview
            while let candidate = view, !(candidate is UICollectionViewCell) {
                view = candidate.superview
            }
            guard let cell = view else { return }
            let bounds = convert(cell.bounds, from: cell)
            guard bounds != reported else { return }
            reported = bounds
            // After this layout pass, since the state it sets is read by the view being laid out.
            DispatchQueue.main.async { [onChange] in onChange(bounds) }
        }
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
