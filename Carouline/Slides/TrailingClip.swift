//
//  TrailingClip.swift
//  Carouline
//

import SwiftUI

/// Clips off what's past the trailing edge, when `isClipping`, leaving the other edges open, so
/// slides still reach under the leading safe area and the bars above and below.
struct TrailingClip: Shape {
    /// Far enough past the open edges to hold anything drawn beyond them.
    private static let reach: CGFloat = 10_000

    let isClipping: Bool

    func path(in rect: CGRect) -> Path {
        let open = rect.insetBy(dx: -Self.reach, dy: -Self.reach)
        return Path(isClipping ? open.divided(atDistance: rect.maxX - open.minX, from: .minXEdge).slice : open)
    }
}

#Preview {
    Color.accentColor
        .frame(width: 400, height: 200)
        .padding(40)
        .frame(width: 300)
        .clipShape(TrailingClip(isClipping: true))
}
