//
//  PhotoThumbnail.swift
//  Carouline
//

import SwiftUI

/// A photo shown whole at a fixed height, as wide as its shape, within `aspectRange`, so its
/// orientation shows at a glance.
struct PhotoThumbnail: View {
    let image: PlacedImage
    let projectID: UUID
    let height: CGFloat
    /// Whether the copy turned out unreadable.
    @Binding var isMissing: Bool

    /// From a tall portrait's three by four to two wide by one high, so a panorama's photo doesn't
    /// crowd out the others, nor a tall one shrink to a sliver.
    static let aspectRange: ClosedRange<CGFloat> = 0.75...2

    var body: some View {
        // Whole, however a cell frames it.
        var whole = image
        whole.crop = ImageCrop()
        return CellPhoto(image: whole, projectID: projectID, isMissing: $isMissing) { absence in
            switch absence {
            case .loading:
                PlaceholderCell(background: .white, isLoading: true)
            case .missing:
                ZStack {
                    PlaceholderCell(background: .white)
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: Self.width(for: image.pixelSize, height: height), height: height)
        .clipShape(.rect(cornerRadius: 6))
    }

    /// The width of a thumbnail `height` high of a photo of `size`.
    static func width(for size: CGSize, height: CGFloat) -> CGFloat {
        guard size.width > 0, size.height > 0 else {
            return height
        }
        return height * min(max(size.width / size.height, aspectRange.lowerBound), aspectRange.upperBound)
    }
}

#Preview {
    @Previewable @State var isMissing = false
    HStack {
        ForEach([CGSize(width: 2048, height: 2730), CGSize(width: 2048, height: 1365), CGSize(width: 4096, height: 1024)], id: \.width) { size in
            let image = PlacedImage(assetIdentifier: nil, pixelWidth: Int(size.width), pixelHeight: Int(size.height))
            PhotoThumbnail(image: image, projectID: UUID(), height: 44, isMissing: $isMissing)
        }
    }
}
