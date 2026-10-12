//
//  ContentView.swift
//  Swipeset
//

import SwiftUI

struct ContentView: View {
    let library: ProjectLibrary
    @State private var isChoosingShape = false
    #if DEBUG
    @Environment(DebugSettings.self) private var debug: DebugSettings?
    #endif

    var body: some View {
        NavigationStack {
            ProjectsScreen(library: library) {
                isChoosingShape = true
            }
        }
        .sheet(isPresented: $isChoosingShape) {
            AspectRatioSheet { ratio in
                _ = library.createProject(aspectRatio: ratio)
            }
        }
        .alert("Couldn't Save Changes", isPresented: showsWriteFailure, presenting: library.writeFailure) { _ in
            Button("OK", role: .cancel) {}
        } message: { failure in
            Text("Swipeset couldn't save your latest changes. \(failure.error.localizedDescription)")
        }
        .task {
            await library.load()
            #if DEBUG
            await openDebugSheet()
            #endif
        }
    }

    private var showsWriteFailure: Binding<Bool> {
        Binding {
            library.writeFailure != nil
        } set: { isShown in
            if !isShown {
                library.writeFailure = nil
            }
        }
    }

    #if DEBUG
    /// Opens `-DebugSheet`'s sheet after a moment, since a presentation on the first frame doesn't render.
    private func openDebugSheet() async {
        guard let sheet = debug?.sheet else {
            return
        }
        try? await Task.sleep(for: .milliseconds(500))
        switch sheet {
        case .newProject: isChoosingShape = true
        }
    }
    #endif
}

#Preview {
    ContentView(library: ProjectLibrary(store: MockProjectStore(projects: SampleProjects.all)))
}
