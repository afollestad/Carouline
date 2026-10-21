//
//  CaptionPopover.swift
//  Carouline
//

import SwiftUI

/// A choice in a slide caption's popover.
struct CaptionChoice: Identifiable {
    let title: String
    let systemImage: String
    var isDestructive = false
    var isEnabled = true
    let action: () -> Void

    var id: String { title }
}

/// A slide caption's choices, listed as a menu lists them, in a popover anchored to the button that
/// opened it. A popover rather than a menu, since a menu's rows lie over the caption's other
/// buttons, which take the taps meant for them. `header` goes above the choices, as a panorama's
/// width does.
struct CaptionPopover<Header: View>: View {
    /// Groups of choices, with a line between each.
    let groups: [[CaptionChoice]]
    @ViewBuilder let header: Header
    /// Runs once the popover has gone, when a sheet or a confirmation it asked for can show.
    let onGone: () -> Void
    /// The screen's text size. The strip caps its own, which the popover would otherwise take, and
    /// popovers stay uncapped, as sheets do.
    @Environment(\.screenDynamicTypeSize) private var screenDynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(groups.indices, id: \.self) { index in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                ForEach(groups[index]) { choice in
                    row(choice)
                }
            }
        }
        .padding(.vertical, 8)
        // As wide as a menu, and wider for larger text, up to what a phone's screen leaves beside
        // the popover's margins, past which titles wrap.
        .frame(minWidth: 240, maxWidth: 340, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        // The caption's glass buttons, smaller text and tint aren't the popover's.
        .buttonStyle(.plain)
        .font(.body)
        .foregroundStyle(Color.primary)
        .dynamicTypeSize(screenDynamicTypeSize)
        .presentationCompactAdaptation(.popover)
        .onDisappear(perform: onGone)
    }

    private func row(_ choice: CaptionChoice) -> some View {
        Button(action: choice.action) {
            CaptionRow(title: choice.title, systemImage: choice.systemImage)
        }
        // Red for a destructive choice, as a menu draws one, and the screen's primary otherwise,
        // since the accent washes out on the glass.
        .foregroundStyle(choice.isDestructive ? Color.red : Color.primary)
        .opacity(choice.isEnabled ? 1 : 0.4)
        .disabled(!choice.isEnabled)
    }
}

/// A row of a caption's popover: its icon, its title, and anything trailing, as a menu row is laid
/// out, a fingertip's height.
struct CaptionRow<Trailing: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(title)
            Spacer(minLength: 16)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .contentShape(.rect)
    }
}

extension CaptionRow where Trailing == EmptyView {
    init(title: String, systemImage: String) {
        self.init(title: title, systemImage: systemImage) {
            EmptyView()
        }
    }
}

extension EnvironmentValues {
    /// The screen's text size outside the strip, which caps its own, for what the strip presents.
    @Entry var screenDynamicTypeSize: DynamicTypeSize = .large
}

#Preview {
    CaptionPopover(
        groups: [
            [CaptionChoice(title: "Move Left", systemImage: "arrow.left", isEnabled: false) {}],
            [CaptionChoice(title: "Delete Slide", systemImage: "trash", isDestructive: true) {}]
        ],
        header: { EmptyView() },
        onGone: {}
    )
}
