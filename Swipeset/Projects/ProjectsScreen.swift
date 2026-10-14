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
    /// Enough rows to read as a list while the library loads, and few enough that a short list
    /// arriving in their place doesn't look like most of it went missing.
    private static let loadingRowCount = 3
    /// On top of the rows' own 5-point spacing, which alone left the first row tight under the
    /// navigation bar.
    private static let topMargin: CGFloat = 8

    var body: some View {
        content
            // The rows fade in over the placeholders that stood in for them.
            .animation(.easeOut(duration: 0.25), value: library.isLoaded)
            // Fades the projects that scroll under the title, which the default cuts off at a
            // solid band with a hairline.
            .scrollEdgeEffectStyle(.soft, for: .top)
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
            // Rather than an empty state, which loading would flash through, or a blank screen.
            loading
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
                    projectRow(project, isInGrid: false)
                        .glassRow()
                }
            }
            if !library.unreadable.isEmpty {
                Section {
                    ForEach(library.unreadable) { project in
                        unreadableRow(project, isInGrid: false)
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
        .contentMargins(.top, Self.topMargin, for: .scrollContent)
    }

    /// The list's cards two to a row, spaced as the list spaces its rows.
    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                    ForEach(library.projects) { project in
                        projectRow(project, isInGrid: true)
                    }
                }
                if !library.unreadable.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                            ForEach(library.unreadable) { project in
                                unreadableRow(project, isInGrid: true)
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
        .contentMargins(.top, Self.topMargin, for: .scrollContent)
        // The cards draw their own glass and colors, which a link's default style would tint.
        .buttonStyle(.plain)
    }

    /// Placeholder rows in the shape of projects', where the list or the grid will put them.
    private var loading: some View {
        Group {
            if usesGrid {
                ScrollView {
                    LazyVGrid(columns: Self.gridColumns, spacing: 10) {
                        ForEach(0..<Self.loadingRowCount, id: \.self) { _ in
                            LoadingRow()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
            } else {
                List {
                    Section {
                        ForEach(0..<Self.loadingRowCount, id: \.self) { _ in
                            LoadingRow()
                                .glassRow()
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .contentMargins(.top, Self.topMargin, for: .scrollContent)
        .scrollDisabled(true)
        // One element for the whole list, rather than rows of placeholder words.
        .accessibilityRepresentation {
            Text("Loading projects")
        }
    }

    private func projectRow(_ project: Project, isInGrid: Bool) -> some View {
        ProjectRow(project: project, isInGrid: isInGrid) { name in
            library.rename(project.id, to: name)
        } onDelete: {
            library.delete(project.id)
        }
    }

    private func unreadableRow(_ project: UnreadableProject, isInGrid: Bool) -> some View {
        UnreadableRow(project: project, isInGrid: isInGrid) {
            library.delete(project)
        }
    }
}

private extension View {
    /// A row as a glass card on the glow, in the list or the grid. An openable card is all a
    /// target, and its glass answers a press and the pointer, as a link's should; another stays
    /// still.
    @ViewBuilder
    func glassCard(isOpenable: Bool) -> some View {
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
    }

    /// A list row that leaves its card apart from the rows around it. The card draws its glass in
    /// the row rather than its background, which drops the list's highlight and sits behind the
    /// touches, so a press would show nothing.
    func glassRow() -> some View {
        listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowSeparator(.hidden)
    }
}

private struct ProjectRow: View {
    let project: Project
    /// Whether it's in the grid, which can't swipe.
    let isInGrid: Bool
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
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .accessibilityHidden(true)
            }
            .glassCard(isOpenable: true)
        }
        // The card draws its own chevron, inside its glass.
        .navigationLinkIndicatorVisibility(.hidden)
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
            if isInGrid {
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
                    SlideView(slide: slide, style: slide.style) { index in
                        if let image = slide.cells[index].image {
                            CellPhoto(
                                image: image,
                                projectID: project.id,
                                blur: LayerGeometry.blurRadius(slide.blur, slideWidth: proxy.size.width),
                                isMissing: .constant(false)
                            ) { absence in
                                // A missing photo leaves the slide's background, as the export does.
                                if absence == .loading {
                                    PlaceholderCell(background: slide.style.background, isLoading: true)
                                }
                            }
                        } else {
                            PlaceholderCell(background: slide.style.background)
                        }
                    }
                    .frame(width: canvas.width, height: canvas.height)
                    .overlay {
                        SlideLayers(
                            layers: slide.layers,
                            projectID: project.id,
                            slideID: slide.id,
                            span: slide.span,
                            background: slide.style.background,
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

/// A project row's shape, with its thumbnail, name and summary as blocks, while the library loads.
private struct LoadingRow: View {
    var body: some View {
        HStack(spacing: 14) {
            // A portrait slide's shape, the default, in an empty project's thumbnail.
            RoundedRectangle(cornerRadius: 4)
                .fill(.fill.tertiary)
                .aspectRatio(AspectRatio.portrait.widthOverHeight, contentMode: .fit)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Untitled Project")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(verbatim: "4:5 Portrait · 3 slides")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            .redacted(reason: .placeholder)
            Spacer(minLength: 0)
        }
        .loadingPulse()
        .glassCard(isOpenable: false)
    }
}

private struct UnreadableRow: View {
    let project: UnreadableProject
    /// Whether it's in the grid, which can't swipe.
    let isInGrid: Bool
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
        .glassCard(isOpenable: false)
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            // The list's swipe action is VoiceOver's way to delete there.
            if isInGrid {
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

#Preview("Loading") {
    NavigationStack {
        ProjectsScreen(library: ProjectLibrary(store: MockProjectStore())) {}
    }
}

#Preview("Empty") {
    NavigationStack {
        ProjectsScreen(library: ProjectLibrary(store: MockProjectStore(), projects: [])) {}
    }
}
