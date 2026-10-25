//
//  ProjectToolbar.swift
//  Carouline
//

import SwiftUI

/// The project screen's Share button, with the popover it opens on a wide screen. A phone's export
/// sheet comes from the screen, as a sheet rather than this popover adapted to one.
struct ProjectToolbar: ToolbarContent {
    let project: Project
    let exporter: SlideExporter
    @Binding var isExporting: Bool
    let onShare: () -> Void
    /// Runs as the popover's content goes, once it no longer covers the screen.
    let onPopoverGone: () -> Void
    @Environment(\.shownPopovers) private var popovers

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            shareButton
        }
    }

    private var shareButton: some View {
        // On a wide screen the export is a popover too, which one still closing would cancel.
        Button("Share Slides", systemImage: "square.and.arrow.up") { popovers.whenGone(onShare) }
            .disabled(project.slides.isEmpty)
            .accessibilityHint("Saves the slides to Photos or shares them to another app")
            .popover(isPresented: $isExporting) {
                ExportSheet(project: project, exporter: exporter)
                    .frame(idealWidth: 420)
                    .onDisappear(perform: onPopoverGone)
                    .countsAsPopover()
            }
    }
}

#Preview {
    @Previewable @State var isExporting = false
    NavigationStack {
        Color.clear
            .toolbar {
                ProjectToolbar(
                    project: SampleProjects.all[0],
                    exporter: SlideExporter(paths: ProjectPaths(root: .temporaryDirectory, temporary: .temporaryDirectory)),
                    isExporting: $isExporting,
                    onShare: { isExporting = true },
                    onPopoverGone: {}
                )
            }
    }
}
