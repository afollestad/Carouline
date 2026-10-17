//
//  ContentView.swift
//  Carouline
//

import SwiftUI

struct ContentView: View {
    let library: ProjectLibrary
    let presets: CustomPresets
    @State private var path: [UUID] = []
    @State private var isChoosingShape = false
    /// A project created in the shape sheet, opened once the sheet is gone, since a push while it
    /// slides away can be dropped.
    @State private var createdProjectID: UUID?
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    /// Opens the shape sheet on its custom page, for `-DebugSheet customRatio`, until it closes.
    @State private var opensCustomRatio = false
    #endif

    var body: some View {
        // Read here rather than only in the sheet's content, so a change to it updates the view
        // and the sheet opens with it.
        let startingDraft = startingDraft
        NavigationStack(path: $path) {
            ProjectsScreen(library: library) {
                isChoosingShape = true
            }
            .navigationDestination(for: UUID.self) { projectID in
                ProjectScreen(library: library, projectID: projectID)
            }
        }
        .sheet(isPresented: $isChoosingShape, onDismiss: shapeSheetClosed) {
            AspectRatioSheet(presets: presets, startsOnCustom: startingDraft) { ratio in
                createdProjectID = library.createProject(aspectRatio: ratio).id
            }
        }
        .alert(library.failure?.title ?? "", isPresented: showsFailure, presenting: library.failure) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text(failure.message)
        }
        .task {
            await library.load()
            #if DEBUG
            await applyDebugSettings()
            #endif
        }
    }

    private var showsFailure: Binding<Bool> {
        Binding {
            library.failure != nil
        } set: { isShown in
            if !isShown {
                library.failure = nil
            }
        }
    }

    /// The custom page's fields to open the shape sheet on, or nil to open it on the presets.
    private var startingDraft: CustomRatioDraft? {
        #if DEBUG
        opensCustomRatio ? CustomRatioDraft() : nil
        #else
        nil
        #endif
    }

    private func shapeSheetClosed() {
        #if DEBUG
        opensCustomRatio = false
        #endif
        openCreatedProject()
    }

    private func openCreatedProject() {
        guard let createdProjectID else {
            return
        }
        self.createdProjectID = nil
        path.append(createdProjectID)
    }

    #if DEBUG
    /// Opens `-DebugOpenProject`'s project, and `-DebugSheet`'s sheet after a moment, since a
    /// presentation on the first frame doesn't render.
    private func applyDebugSettings() async {
        if let index = debug?.openProjectIndex, library.projects.indices.contains(index) {
            path = [library.projects[index].id]
        }
        guard let sheet = debug?.sheet, !sheet.opensInProject else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        opensCustomRatio = sheet == .customRatio
        isChoosingShape = true
    }
    #endif
}

#Preview {
    ContentView(library: ProjectLibrary(store: MockProjectStore(projects: SampleProjects.all)), presets: CustomPresets(presets: []))
}
