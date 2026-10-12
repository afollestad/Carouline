//
//  ProjectsScreen.swift
//  Swipeset
//

import SwiftUI

/// The app's root screen, listing every project.
struct ProjectsScreen: View {
    let onNewProject: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "rectangle.stack")
        } description: {
            Text("Start a project to lay out a carousel of photos.")
        } actions: {
            Button("New Project", action: onNewProject)
                .buttonStyle(.glassProminent)
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Project", systemImage: "plus", action: onNewProject)
                    .accessibilityHint("Choose the shape of the new project's slides")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProjectsScreen {}
    }
}
