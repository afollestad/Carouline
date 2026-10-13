//
//  ProjectsScreen.swift
//  Swipeset
//

import SwiftUI

/// The app's root screen, listing every project.
struct ProjectsScreen: View {
    let library: ProjectLibrary
    let onNewProject: () -> Void
    @State private var size: CGSize = .zero
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Two cards a row fill an iPad in landscape without stretching a row's few words across it,
    /// and leave each name room that a third would cut short.
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    private static let unreadableNote = "Swipeset leaves these as they are until you delete them."

    var body: some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                self.size = size
            }
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
        } else if usesGrid {
            grid
        } else {
            list
        }
    }

    /// Whether the projects sit in a grid, on a regular-width screen wider than it's tall, as an
    /// iPad's in landscape. A narrow window and portrait keep the list, and its swipe to delete.
    private var usesGrid: Bool {
        horizontalSizeClass == .regular && size.width > size.height
    }

    private var list: some View {
        List {
            Section {
                ForEach(library.projects) { project in
                    projectRow(project, isCard: false)
                        .glassRow()
                }
            }
            if !library.unreadable.isEmpty {
                Section {
                    ForEach(library.unreadable) { project in
                        unreadableRow(project, isCard: false)
                            .glassRow()
                    }
                    // A row rather than the section's footer, which a plain list draws on an
                    // opaque band across the glow.
                    Text(Self.unreadableNote)
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

    /// The list's cards two to a row, spaced as the list spaces its rows.
    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                    ForEach(library.projects) { project in
                        projectRow(project, isCard: true)
                    }
                }
                if !library.unreadable.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                            ForEach(library.unreadable) { project in
                                unreadableRow(project, isCard: true)
                            }
                        }
                        Text(Self.unreadableNote)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
        }
        // The cards draw their own glass and colors, which a link's default style would tint.
        .buttonStyle(.plain)
    }

    private func projectRow(_ project: Project, isCard: Bool) -> some View {
        ProjectRow(project: project, isCard: isCard) { name in
            library.rename(project.id, to: name)
        } onDelete: {
            library.delete(project.id)
        }
    }

    private func unreadableRow(_ project: UnreadableProject, isCard: Bool) -> some View {
        UnreadableRow(project: project, isCard: isCard) {
            library.delete(project)
        }
    }
}

private extension View {
    /// A row of the grid as a glass card on the glow, with the padding the list's rows have
    /// inside their glass. An openable card is all a target, and its glass answers a press and
    /// the pointer, as a link's should; another stays still.
    @ViewBuilder
    func glassCard(_ isCard: Bool, isOpenable: Bool) -> some View {
        if isCard {
            let card = padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect(cornerRadius: 24))
                .contentShape([.contextMenuPreview, .hoverEffect], .rect(cornerRadius: 24))
            if isOpenable {
                card
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                    .hoverEffect(.highlight)
            } else {
                card
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
        } else {
            self
        }
    }

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
    /// Whether it's a card in the grid, which draws its own glass and chevron, and can't swipe.
    let isCard: Bool
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
                if isCard {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                }
            }
            .glassCard(isCard, isOpenable: true)
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
        .accessibilityActions {
            // The list's swipe action is VoiceOver's way to delete there.
            if isCard {
                Button("Delete") {
                    isConfirmingDelete = true
                }
            }
        }
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

/// The project's first slide, or its empty shape before it has one. A panorama shows its first
/// slide, as the carousel opens on it.
private struct ProjectThumbnail: View {
    let project: Project

    var body: some View {
        Group {
            if let slide = project.slides.first {
                GeometryReader { proxy in
                    let canvas = CGSize(width: proxy.size.width * CGFloat(slide.span), height: proxy.size.height)
                    SlideView(slide: slide, style: project.style) { index in
                        if let image = slide.cells[index].image {
                            CellPhoto(image: image, projectID: project.id)
                        } else {
                            PlaceholderCell(background: project.style.background)
                        }
                    }
                    .frame(width: canvas.width, height: canvas.height)
                    .overlay {
                        SlideLayers(
                            layers: slide.layers,
                            projectID: project.id,
                            slideID: slide.id,
                            span: slide.span,
                            background: project.style.background,
                            size: canvas
                        )
                    }
                }
                .clipped()
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
    /// Whether it's a card in the grid, which draws its own glass and can't swipe.
    let isCard: Bool
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
        .glassCard(isCard, isOpenable: false)
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            // The list's swipe action is VoiceOver's way to delete there.
            if isCard {
                Button("Delete") {
                    isConfirmingDelete = true
                }
            }
        }
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
