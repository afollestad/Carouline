//
//  TrayRemovalBar.swift
//  Carouline
//

import SwiftUI

/// Glass along the bottom of the project screen in the tray's place, asking whether to take the
/// tray photos a pick left out of the tray: the photos, what happened, and the two answers. In the
/// band rather than an alert, which can't show until the picker has finished closing, and so would
/// have to wait on a guess of how long that takes.
struct TrayRemovalBar: View {
    /// The tray photos waiting on an answer.
    let photos: [TrayPhoto]
    let projectID: UUID
    let onKeep: () -> Void
    let onRemove: () -> Void

    /// As many as fit beside the question without crowding it.
    private static let shownCount = 3

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: -12) {
                        ForEach(photos.prefix(Self.shownCount)) { photo in
                            Thumbnail(photo: photo, projectID: projectID)
                        }
                    }
                    .accessibilityHidden(true)
                    Text(question)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(announcement)
                }
                .padding(.leading, 6)
                .padding(.trailing, 12)
                .frame(height: 48)
                .glassEffect(.regular, in: Capsule())
                .accessibilityElement(children: .combine)
                Button("Keep", action: onKeep)
                    .buttonStyle(.glass)
                    .accessibilityHint("Leaves the photos in the tray")
                Button("Remove", role: .destructive, action: onRemove)
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .accessibilityHint("Takes the photos out of the tray. Any on slides stay there.")
            }
            .controlSize(.large)
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        // The bar's width holds the controls, not more text.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onAppear {
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    /// Short enough for two lines beside the answers on a phone.
    private var question: String {
        photos.count == 1 ? "1 photo not in your pick" : "\(photos.count) photos not in your pick"
    }

    private var announcement: String {
        let photos = photos.count == 1 ? "1 tray photo was" : "\(photos.count) tray photos were"
        return "\(photos) left out of your pick. Keep them in the tray, or remove them?"
    }
}

/// One of the photos, as a small round-cornered square ringed so overlapping ones stay apart.
private struct Thumbnail: View {
    let photo: TrayPhoto
    let projectID: UUID
    @State private var isMissing = false

    var body: some View {
        var whole = photo.image
        whole.crop = ImageCrop()
        return CellPhoto(image: whole, projectID: projectID, isMissing: $isMissing) { absence in
            PlaceholderCell(background: .white, isLoading: absence == .loading)
        }
        .frame(width: 36, height: 36)
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.background, lineWidth: 1.5)
        }
    }
}

#Preview {
    let project = SampleProjects.all[0]
    VStack {
        Spacer()
        TrayRemovalBar(photos: Array(project.tray.suffix(2)), projectID: project.id, onKeep: {}, onRemove: {})
    }
    .background { GlowBackdrop() }
}
