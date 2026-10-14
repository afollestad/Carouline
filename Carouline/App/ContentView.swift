//
//  ContentView.swift
//  Carouline
//

import SwiftUI

struct ContentView: View {
    let library: ProjectLibrary
    @State private var path: [UUID] = []
    @State private var isChoosingShape = false
    /// A project created in the shape sheet, opened once the sheet is gone, since a push while it
    /// slides away can be dropped.
    @State private var createdProjectID: UUID?
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    var body: some View {
        NavigationStack(path: $path) {
            ProjectsScreen(library: library) {
                isChoosingShape = true
            }
            .navigationDestination(for: UUID.self) { projectID in
                ProjectScreen(library: library, projectID: projectID)
            }
        }
        .sheet(isPresented: $isChoosingShape, onDismiss: openCreatedProject) {
            AspectRatioSheet { ratio in
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
        guard debug?.sheet == .newProject else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        isChoosingShape = true
    }
    #endif
}

#Preview {
    ContentView(library: ProjectLibrary(store: MockProjectStore(projects: SampleProjects.all)))
}
