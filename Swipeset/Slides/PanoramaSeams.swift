//
//  PanoramaSeams.swift
//  Swipeset
//

import SwiftUI

/// Where a panorama's export cuts it into slides: a line between each pair.
struct SeamLines: Shape {
    let span: Int

    func path(in rect: CGRect) -> Path {
        Path { path in
            for seam in 1..<max(1, span) {
                let x = rect.minX + rect.width * CGFloat(seam) / CGFloat(span)
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
        }
    }
}

/// A panorama's cuts dashed over it, white edged in black, so they show on a bright sky, a dark
/// sea, or a background of either. Decorative, since the caption names the slides, and passed
/// through to the photo, which drags and pinches beneath them.
struct PanoramaSeams: View {
    let span: Int

    private static let dash: [CGFloat] = [6, 4]

    var body: some View {
        ZStack {
            SeamLines(span: span)
                .stroke(.black.opacity(0.4), style: StrokeStyle(lineWidth: 3, dash: Self.dash))
            SeamLines(span: span)
                .stroke(.white, style: StrokeStyle(lineWidth: 1, dash: Self.dash))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 0) {
        PanoramaSeams(span: 3)
            .background(.white)
        PanoramaSeams(span: 3)
            .background(.black)
    }
    .frame(width: 330, height: 220)
}
