//
//  ProjectsScreen.swift
//  Swipeset
//

import SwiftUI

/// The app's root screen, listing every project.
struct ProjectsScreen: View {
    let library: ProjectLibrary
    let onNewProject: () -> Void

    var body: some View {
        content
            .background {
                GlowBackdrop()
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Project", systemImage: "plus", action: onNewProject)
                        .accessibilityHint("Choose the shape of the new project's slides")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if !library.isLoaded {
            // Loading takes a moment, which an empty state would flash through.
            Color.clear
        } else if library.projects.isEmpty, library.unreadable.isEmpty {
            ContentUnavailableView {
                Label("No Projects", systemImage: "rectangle.stack")
            } description: {
                Text("Start a project to lay out a carousel of photos.")
            } actions: {
                Button("New Project", action: onNewProject)
                    .buttonStyle(.glassProminent)
            }
        } else {
            List {
                Section {
                    ForEach(library.projects) { project in
                        ProjectRow(project: project) { name in
                            library.rename(project.id, to: name)
                        } onDelete: {
                            library.delete(project.id)
                        }
                        .glassRow()
                    }
                }
                if !library.unreadable.isEmpty {
                    Section {
                        ForEach(library.unreadable) { project in
                            UnreadableRow(project: project) {
                                library.delete(project)
                            }
                            .glassRow()
                        }
                        // A row rather than the section's footer, which a plain list draws on an
                        // opaque band across the glow.
                        Text("Swipeset leaves these as they are until you delete them.")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 32, bottom: 4, trailing: 32))
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

private extension View {
    /// A row as its own glass card on the glow, apart from the rows around it.
    func glassRow() -> some View {
        listRowBackground(
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
        )
        .listRowInsets(EdgeInsets(top: 15, leading: 30, bottom: 15, trailing: 30))
        .listRowSeparator(.hidden)
    }
}

private struct ProjectRow: View {
    let project: Project
    let onRename: (String) -> Void
    let onDelete: () -> Void
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var isConfirmingDelete = false

    var body: some View {
        NavigationLink(value: project.id) {
            HStack(spacing: 14) {
                ProjectThumbnail(project: project)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(project.summary)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .accessibilityLabel("\(project.name), \(project.spokenSummary)")
        // Without the destructive role, which would start removing the row before the confirmation.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash") {
                isConfirmingDelete = true
            }
            .tint(.red)
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil", action: startRenaming)
            Button("Delete", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        }
        .accessibilityAction(named: "Rename", startRenaming)
        .alert("Rename Project", isPresented: $isRenaming) {
            TextField("Name", text: $draftName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                onRename(draftName)
            }
        }
        .confirmationDialog("Delete “\(project.name)”?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Project", role: .destructive, action: onDelete)
        } message: {
            Text("Its slides and the copies of its photos are deleted. The originals stay in your photo library.")
        }
    }

    private func startRenaming() {
        draftName = project.name
        isRenaming = true
    }
}

/// The project's first slide, or its empty shape before it has one.
private struct ProjectThumbnail: View {
    let project: Project

    var body: some View {
        Group {
            if let slide = project.slides.first {
                SlideView(slide: slide, style: project.style) { index in
                    if let image = slide.cells[index].image {
                        CellPhoto(image: image, projectID: project.id)
                    } else {
                        PlaceholderCell(background: project.style.background)
                    }
                }
                .overlay {
                        Rectangle()
                            .strokeBorder(.separator, lineWidth: 0.5)
                    }
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.fill.tertiary)
                    .strokeBorder(.separator)
            }
        }
        .aspectRatio(project.aspectRatio.widthOverHeight, contentMode: .fit)
        .frame(width: 56, height: 56)
        .accessibilityHidden(true)
    }
}

private struct UnreadableRow: View {
    let project: UnreadableProject
    let onDelete: () -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Color.secondary)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Can't Open Project")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", systemImage: "trash") {
                isConfirmingDelete = true
            }
            .tint(.red)
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
                isConfirmingDelete = true
            }
        }
        .confirmationDialog("Delete This Project?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Project", role: .destructive, action: onDelete)
        } message: {
            Text("It can't be opened, so its slides and photo copies are deleted unseen.")
        }
    }

    private var reason: String {
        switch project.reason {
        case .newerVersion: "Saved by a newer version of Swipeset. Update the app to open it."
        case .damaged: "Its file is damaged."
        }
    }
}

#Preview("Projects") {
    NavigationStack {
        ProjectsScreen(library: ProjectLibrary(store: MockProjectStore(), projects: SampleProjects.all)) {}
    }
}

#Preview("Empty") {
    NavigationStack {
        ProjectsScreen(library: ProjectLibrary(store: MockProjectStore(), projects: [])) {}
    }
}
