//
//  SlideBackdrop.swift
//  Carouline
//

import SwiftUI

/// The slide in front, its photos blurred past recognition over the glow, so the project screen
/// reads as frosted glass lit by the slides behind it. Empty cells and missing photos leave the
/// glow showing.
struct SlideBackdrop: View {
    let slide: Slide?
    let projectID: UUID
    let aspectRatio: AspectRatio
    /// Which of a panorama's slides is in the middle of the strip, read here alone, so a cut the
    /// strip crosses redraws the backdrop rather than the screen.
    var layerSession: LayerSession?
    @Environment(\.colorScheme) private var colorScheme

    /// Small enough that the photos decode at their smallest size and blur into a small image,
    /// since the blur leaves nothing finer to see.
    private static let renderWidth: CGFloat = 60
    /// On screen, after scaling up.
    private static let blurRadius: CGFloat = 48

    var body: some View {
        let frontIndex = slide.flatMap { layerSession?.frontSlideIndex(of: $0.id) }
        GeometryReader { proxy in
            ZStack {
                GlowBackdrop()
                if let slide, slide.cells.contains(where: { $0.image != nil }) {
                    photos(of: slide, from: frontIndex, filling: proxy.size)
                        .id(slide.id)
                        .transition(.opacity)
                    scrim
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.6), value: slide?.id)
        .animation(.smooth(duration: 0.6), value: frontIndex)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Shade behind the navigation bar, where the subtitle's secondary text would wash out over a
    /// bright photo.
    private var scrim: some View {
        LinearGradient(
            colors: [colorScheme == .dark ? .black.opacity(0.45) : .white.opacity(0.6), .clear],
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: 0.25)
        )
    }

    /// The slide's photos where its cells put them, blurred small and scaled up to fill `size`.
    /// A panorama renders each of its slides as small as one, and the screen fills from slide
    /// `frontIndex`, the one in the middle of the strip, or else from its middle.
    private func photos(of slide: Slide, from frontIndex: Int?, filling size: CGSize) -> some View {
        let small = CGSize(width: Self.renderWidth * CGFloat(slide.span), height: Self.renderWidth / aspectRatio.widthOverHeight)
        // Half again past one slide filling it, so the blur's fade at the photos' edges falls off
        // the screen wherever the slide in front sits along a panorama.
        let scale = max(size.width / Self.renderWidth, size.height / small.height) * 1.5
        let slidesFromMiddle = frontIndex.map { CGFloat(slide.span) / 2 - (CGFloat($0) + 0.5) } ?? 0
        return SlideCells(layout: slide.layout, style: slide.style, span: slide.span) {
            ForEach(slide.cells.indices, id: \.self) { index in
                if let image = slide.cells[index].image {
                    CellPhoto(image: image, projectID: projectID)
                } else {
                    Color.clear
                }
            }
        }
        .frame(width: small.width, height: small.height)
        .saturation(1.3)
        .blur(radius: Self.blurRadius / scale)
        // Dimmed in dark mode, and faded into the glow in light mode, so text over them keeps
        // its contrast.
        .colorMultiply(colorScheme == .dark ? Color(white: 0.5) : .white)
        .opacity(colorScheme == .dark ? 1 : 0.5)
        // Blurred once into a small image, rather than again on every frame the strip scrolls.
        .drawingGroup()
        .scaleEffect(scale)
        .offset(x: slidesFromMiddle * Self.renderWidth * scale)
        .frame(width: size.width, height: size.height)
    }
}

#Preview {
    let project = SampleProjects.all[0]
    SlideBackdrop(slide: project.slides.first, projectID: project.id, aspectRatio: project.aspectRatio)
}
