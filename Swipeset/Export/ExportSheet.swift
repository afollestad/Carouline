//
//  ExportSheet.swift
//  Swipeset
//

import SwiftUI

/// Writes a project's slides out, previews them, and saves them to Photos or shares them.
struct ExportSheet: View {
    let project: Project
    let exporter: any SlideExporting
    @State private var phase = Phase.preparing
    @State private var saving = SaveState.idle
    @Environment(\.photoSaver) private var photoSaver
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    /// Instagram's limit for a carousel, the most common place these go.
    private static let carouselLimit = 20

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
            Group {
                switch phase {
                case .preparing:
                    ProgressView(project.carouselSlideCount == 1 ? "Preparing 1 slide…" : "Preparing \(project.carouselSlideCount) slides…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let result):
                    ready(result)
                case .failed:
                    ContentUnavailableView(
                        "Couldn't Prepare Slides",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Swipeset couldn't write the slides out. Close this and try again.")
                    )
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetCloseItem {
                    dismiss()
                }
            }
        }
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
        .presentationDetents([.medium, .large])
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    private func ready(_ result: ExportResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                preview(result)
                notes(result)
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await save(result.files)
                        }
                    } label: {
                        saveLabel
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(saving == .saving || saving == .saved)
                    ShareLink(items: result.files) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .accessibilityHint("Sends every slide, in order, to another app")
                }
                .controlSize(.large)
                .padding(.horizontal)
                if saving == .denied {
                    deniedNote
                } else if saving == .failed {
                    Text("Swipeset couldn't save the slides. Try again.")
                        .font(.footnote)
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(.vertical)
        }
    }

    private func preview(_ result: ExportResult) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(result.slides) { slide in
                    if let thumbnail = slide.thumbnail {
                        Image(decorative: thumbnail, scale: 1)
                            .resizable()
                            .aspectRatio(project.aspectRatio.widthOverHeight, contentMode: .fit)
                            .frame(height: 140)
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
            Text("Swipeset isn't allowed to add to your photo library.")
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
                    SampleImages.image(
                        for: image.id,
                        width: image.pixelWidth,
                        height: image.pixelHeight,
                        maxPixelSize: Int(max(size.width, size.height))
                    )
                }
            )
            .environment(\.photoSaver, MockPhotoSaver())
        }
}
