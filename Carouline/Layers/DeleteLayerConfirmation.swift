//
//  DeleteLayerConfirmation.swift
//  Carouline
//

import SwiftUI

/// Asks before a layer editor deletes its layer, in a popover from the editor's trash laid out as
/// the system's confirmation dialog is, with its title, note and button where the dialog has them.
/// Not the dialog itself: from a title bar button, a `confirmationDialog` runs its action only once
/// it has folded back into the button, about 1.1 s after the tap and well after it looks gone, so
/// the layer stayed on the slide and the editor open meanwhile. This one's button deletes at once.
struct DeleteLayerConfirmation: View {
    /// Whether the layer is a picture, whose copy goes with it.
    let isPicture: Bool
    /// The width of the page it comes from, which it widens to at accessibility sizes.
    let pageWidth: CGFloat
    let onDelete: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The system dialog's width, which its title and note wrap within.
    private static let dialogWidth: CGFloat = 240
    /// How far in from a phone's sheet the dialog keeps as it widens at accessibility sizes.
    private static let widenedInset: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delete Layer?")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if isPicture {
                    Text("Its picture is removed from the project. The original stays in your photo library.")
                        .font(.subheadline)
                        // Gray, as the system's dialog draws its message, which this stands in for,
                        // though other text on glass takes the primary color.
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // As far in as the dialog's text, past its button's edges.
            .padding(.horizontal, 14)
            Button("Delete Layer", role: .destructive, action: onDelete)
                .buttonStyle(DialogButtonStyle())
                .padding(.top, 20)
        }
        .padding(.horizontal, 16)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .frame(width: width)
        // A popover on a phone too, growing out of the trash as the dialog did, rather than a sheet.
        .presentationCompactAdaptation(.popover)
    }

    /// The dialog's width, or at accessibility sizes nearly the page's, as the dialog widens to fit
    /// its larger text. Never left to the text, whose ideal width is all on one line, which would
    /// run the popover off the screen.
    private var width: CGFloat {
        guard dynamicTypeSize.isAccessibilitySize else {
            return Self.dialogWidth
        }
        return max(Self.dialogWidth, pageWidth - 2 * Self.widenedInset)
    }
}

/// The dialog's button: its title in red on a gray capsule across the popover, darker while pressed.
private struct DialogButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(configuration.isPressed ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.tertiary), in: .capsule)
            .contentShape(.capsule)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    Button("Delete Layer", systemImage: "trash", role: .destructive) {
        isPresented = true
    }
    .tint(.red)
    .popover(isPresented: $isPresented) {
        DeleteLayerConfirmation(isPicture: true, pageWidth: 386) {
            isPresented = false
        }
    }
}
