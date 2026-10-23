//
//  ConfirmationPopover.swift
//  Carouline
//

import SwiftUI

extension View {
    /// Asks `title`, with `message` under it, in a popover from this view laid out as the system's
    /// confirmation dialog is, whose buttons each close it and act at once. In place of
    /// `confirmationDialog`, which runs its action only once it has finished closing: about 0.55 s
    /// after the tap, or 1.1 s from a title bar button, well after it looks gone, so the change it
    /// asked about lagged behind it.
    func confirmationPopover<Actions: View>(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        // Built now, in the body of the view it comes from, so that view tracks what they read, as
        // it wouldn't from a closure run only once the popover shows, which then shows stale state.
        let actions = actions()
        return popover(isPresented: isPresented) {
            ConfirmationPopover(title: title, message: message, actions: actions)
        }
    }
}

/// A confirmation's title, note and buttons, where the system's dialog has them.
struct ConfirmationPopover<Actions: View>: View {
    let title: String
    let message: String?
    let actions: Actions
    @Environment(\.screenMetrics) private var screen
    /// The screen's text size. The strip caps its own, which a popover from a slide would otherwise
    /// take, and popovers stay uncapped, as sheets do.
    @Environment(\.screenDynamicTypeSize) private var screenDynamicTypeSize

    var body: some View {
        // Scrolls only when the popover can't fit it whole, as under a slide on an iPad at the largest
        // text sizes. UIKit shrinks a popover that doesn't fit, where it moves the dialog over what
        // it points at, and would cut off its title and buttons.
        ViewThatFits(in: .vertical) {
            content
            ScrollView {
                content
            }
        }
        .frame(width: screen.confirmationWidth(at: screenDynamicTypeSize))
        .dynamicTypeSize(screenDynamicTypeSize)
        // A popover on a phone too, growing out of what it asks about as the dialog does, rather than
        // a sheet.
        .presentationCompactAdaptation(.popover)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading
                // As far in as the dialog's text, past its buttons' edges.
                .padding(.horizontal, 14)
            VStack(spacing: 8) {
                actions
            }
            .buttonStyle(ConfirmationButtonStyle())
            .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var heading: some View {
        if let message {
            VStack(alignment: .leading, spacing: 8) {
                titleText
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    // Gray, as the system's dialog draws its message, which this stands in for,
                    // though other text on glass takes the primary color.
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            // A lone title reads as the dialog's does: regular, centered while it fits a line, and
            // leading once it wraps.
            ViewThatFits(in: .horizontal) {
                titleText
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                titleText
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.body)
        }
    }

    private var titleText: some View {
        Text(title)
            // Primary, rather than whatever the view it comes from draws its text in.
            .foregroundStyle(Color.primary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Closes the popover and acts in the same moment, for each button the confirmation offers.
private struct ConfirmationButtonStyle: PrimitiveButtonStyle {
    /// The popover's own.
    @Environment(\.dismiss) private var dismiss

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) {
            dismiss()
            configuration.trigger()
        } label: {
            configuration.label
        }
        // On the button itself, since from anywhere above it the button would take this style again.
        .buttonStyle(DialogButtonStyle())
    }
}

/// The dialog's button: its title in red for a destructive one, or else the primary color, which
/// the accent washes out beside on the glass, on a gray capsule across the popover, darker while
/// pressed.
private struct DialogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(configuration.role == .destructive ? Color.red : Color.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(configuration.isPressed ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.tertiary), in: .capsule)
            .contentShape(.capsule)
    }
}

#Preview("With a note") {
    @Previewable @State var isPresented = true
    Button("Delete Layer", systemImage: "trash", role: .destructive) {
        isPresented = true
    }
    .tint(.red)
    .confirmationPopover(
        "Delete Layer?",
        isPresented: $isPresented,
        message: "Its picture is removed from the project. The original stays in your photo library."
    ) {
        Button("Delete Layer", role: .destructive) {}
    }
}

#Preview("Choices") {
    @Previewable @State var isPresented = true
    Button("Remove") {
        isPresented = true
    }
    .confirmationPopover("Remove from Which Slide?", isPresented: $isPresented) {
        Button("Slide 1", role: .destructive) {}
        Button("Slide 2", role: .destructive) {}
        Button("Remove from All", role: .destructive) {}
    }
}
