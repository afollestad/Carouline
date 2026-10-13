//
//  ProjectToolbar.swift
//  Swipeset
//

import SwiftUI

/// The project screen's Style and Share buttons, each with the popover it opens.
struct ProjectToolbar: ToolbarContent {
    let project: Project
    let exporter: SlideExporter
    @Binding var isStyling: Bool
    @Binding var isExporting: Bool
    /// The style being edited, which the slides draw while the style sheet is open.
    @Binding var style: SlideStyle
    let onStyle: () -> Void
    let onShare: () -> Void
    let onCommitStyle: () -> Void
    /// Runs as either popover's content goes, once it no longer covers the screen.
    let onPopoverGone: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            styleButton
        }
        // Apart, so the two read as separate actions rather than one control.
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            shareButton
        }
    }

    private var styleButton: some View {
        Button("Style", systemImage: "slider.horizontal.3", action: onStyle)
            .accessibilityHint("Sets the spacing, border and background of every slide")
            // A sheet on iPhone, and on iPad a popover, which leaves the slides in view beside it.
            .popover(isPresented: $isStyling) {
                StyleSheet(style: $style, onCommit: onCommitStyle)
                    .frame(idealWidth: 380, idealHeight: 540)
                    .onDisappear(perform: onPopoverGone)
            }
    }

    private var shareButton: some View {
        Button("Share Slides", systemImage: "square.and.arrow.up", action: onShare)
            .disabled(project.slides.isEmpty)
            .accessibilityHint("Saves the slides to Photos or shares them to another app")
            .popover(isPresented: $isExporting) {
                ExportSheet(project: project, exporter: exporter)
                    .frame(idealWidth: 420, idealHeight: 480)
                    .onDisappear(perform: onPopoverGone)
            }
    }
}

#Preview {
    @Previewable @State var isStyling = false
    @Previewable @State var isExporting = false
    @Previewable @State var style = SlideStyle.standard
    NavigationStack {
        Color.clear
            .toolbar {
                ProjectToolbar(
                    project: SampleProjects.all[0],
                    exporter: SlideExporter(paths: ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)),
                    isStyling: $isStyling,
                    isExporting: $isExporting,
                    style: $style,
                    onStyle: { isStyling = true },
                    onShare: { isExporting = true },
                    onCommitStyle: {},
                    onPopoverGone: {}
                )
            }
    }
}
