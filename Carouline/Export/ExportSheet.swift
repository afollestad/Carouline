//
//  ExportSheet.swift
//  Carouline
//

import SwiftUI

/// Writes a project's slides out, previews them, and saves them to Photos or shares them.
struct ExportSheet: View {
    let project: Project
    let exporter: any SlideExporting
    @State private var phase = Phase.preparing
    @State private var saving = SaveState.idle
    /// How tall the title bar and the content are, which the sheet and the popover fit, rather than
    /// leaving blank space below the buttons. A stand-in until the first layout measures it.
    @State private var height: CGFloat = 480
    @Environment(\.photoSaver) private var photoSaver
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    /// Instagram's limit for a carousel, the most common place these go.
    private static let carouselLimit = 20
    /// The previews' height, which the spinner holds while they're prepared, so the sheet opens at
    /// about the height it keeps.
    private static let previewHeight: CGFloat = 140

    private enum Phase {
        case preparing
        case ready(ExportResult)
        case failed
    }

    private enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case denied
        case failed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                switch phase {
                case .preparing:
                    content(nil)
                case .ready(let result):
                    content(result)
                case .failed:
                    ContentUnavailableView(
                        "Couldn't Prepare Slides",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Carouline couldn't write the slides out. Close this and try again.")
                    )
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // With the title bar the content scrolls under, but not a phone's bottom safe area,
                // which its sheet reaches over past its height.
                geometry.contentInsets.top + geometry.contentSize.height
            } action: { _, height in
                self.height = height
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem {
                    dismiss()
                }
            }
        }
        // A popover's height, which a sheet's detent sets instead.
        .frame(idealHeight: height)
        .task {
            do {
                phase = .ready(try await exporter.export(project))
            } catch {
                phase = .failed
            }
        }
        .sensoryFeedback(.success, trigger: saving) { _, state in
            state == .saved
        }
        // Taller only shows blank space, and content taller than the screen scrolls in a sheet
        // already at its full height.
        .presentationDetents([.height(height)])
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    /// The previews and buttons, or, while the slides are prepared, a spinner in the previews'
    /// place and the buttons disabled.
    private func content(_ result: ExportResult?) -> some View {
        VStack(spacing: 20) {
            if let result {
                preview(result)
                notes(result)
            } else {
                ProgressView(project.carouselSlideCount == 1 ? "Preparing 1 slide…" : "Preparing \(project.carouselSlideCount) slides…")
                    .frame(maxWidth: .infinity, minHeight: Self.previewHeight)
            }
            VStack(spacing: 12) {
                Button {
                    if let result {
                        Task {
                            await save(result.files)
                        }
                    }
                } label: {
                    saveLabel
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(result == nil || saving == .saving || saving == .saved)
                ShareLink(items: result?.files ?? []) {
                    Label("Share…", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .disabled(result == nil)
                .accessibilityHint("Sends every slide, in order, to another app")
            }
            .controlSize(.large)
            .padding(.horizontal)
            if saving == .denied {
                deniedNote
            } else if saving == .failed {
                Text("Carouline couldn't save the slides. Try again.")
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
            }
        }
        .padding(.vertical)
    }

    private func preview(_ result: ExportResult) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(result.slides) { slide in
                    if let thumbnail = slide.thumbnail {
                        Image(decorative: thumbnail, scale: 1)
                            .resizable()
                            .aspectRatio(project.aspectRatio.widthOverHeight, contentMode: .fit)
                            .frame(height: Self.previewHeight)
                            .overlay {
                                Rectangle()
                                    .strokeBorder(.separator, lineWidth: 0.5)
                            }
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.slides.count == 1 ? "Preview of 1 slide" : "Preview of \(result.slides.count) slides")
    }

    @ViewBuilder
    private func notes(_ result: ExportResult) -> some View {
        let notes = Self.notes(for: result)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(notes, id: \.self) { note in
                    // Primary, since gray washes out on the glass over a bright slide.
                    Label(note, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Color.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    private static func notes(for result: ExportResult) -> [String] {
        var notes: [String] = []
        if result.emptyCells > 0 {
            notes.append(result.emptyCells == 1
                ? "1 empty cell exports as the background."
                : "\(result.emptyCells) empty cells export as the background.")
        }
        if result.missingPhotos > 0 {
            notes.append(result.missingPhotos == 1
                ? "1 unavailable photo exports as the background."
                : "\(result.missingPhotos) unavailable photos export as the background.")
        }
        if result.missingLayerImages > 0 {
            notes.append(result.missingLayerImages == 1
                ? "1 unavailable layer image is left out."
                : "\(result.missingLayerImages) unavailable layer images are left out.")
        }
        if result.slides.count > carouselLimit {
            notes.append("Instagram takes up to \(carouselLimit) slides in a post.")
        }
        return notes
    }

    @ViewBuilder
    private var saveLabel: some View {
        switch saving {
        case .idle, .denied, .failed:
            Label("Save to Photos", systemImage: "square.and.arrow.down")
        case .saving:
            Label {
                Text("Saving…")
            } icon: {
                ProgressView()
            }
        case .saved:
            Label("Saved to Photos", systemImage: "checkmark")
        }
    }

    private var deniedNote: some View {
        VStack(spacing: 8) {
            Text("Carouline isn't allowed to add to your photo library.")
                .font(.footnote)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let settings = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settings)
                }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal)
    }

    private func save(_ files: [URL]) async {
        saving = .saving
        do {
            try await photoSaver.save(files)
            saving = .saved
        } catch PhotoSaveError.denied {
            saving = .denied
        } catch {
            saving = .failed
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ExportSheet(
                project: SampleProjects.all[0],
                exporter: SlideExporter(
                    paths: ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)
                ) { image, _, size in
                    SampleImages.image(for: image, maxPixelSize: Int(max(size.width, size.height)))
                }
            )
            .environment(\.photoSaver, MockPhotoSaver())
        }
}
