//
//  CaptionLabelWidths.swift
//  Carouline
//

import SwiftUI

/// How wide the strip's captions are, from their labels' widths, measured ahead for every shape,
/// and one caption measured on the strip, which every caption is as much wider than its label as.
struct CaptionWidths: Equatable {
    /// Each label's width, by `slidesNameShape`, from `CaptionLabelWidths`.
    var labels: [String: CGFloat] = [:]
    private var sample: Sample?

    private struct Sample: Equatable {
        let shape: String
        let width: CGFloat
    }

    /// Keeps a caption `width` wide naming `numbers` to measure the others by, unless the one kept
    /// already gives its width within a point. So a rounding doesn't move every card as slides
    /// change, while a new text size or weight, which every caption changes width for, does.
    mutating func sample(_ width: CGFloat, naming numbers: ClosedRange<Int>) {
        guard CaptionLabelWidths.shapes.contains(numbers.slidesNameShape) else {
            return
        }
        if let known = self.width(naming: numbers), abs(known - width) <= 1 {
            return
        }
        sample = Sample(shape: numbers.slidesNameShape, width: width)
    }

    /// The width of the caption naming `numbers`, known before any caption takes its label's
    /// shape, or nil until a caption and the labels are measured.
    func width(naming numbers: ClosedRange<Int>) -> CGFloat? {
        guard let sample, let sampleLabel = labels[sample.shape], let label = labels[numbers.slidesNameShape] else {
            return nil
        }
        return sample.width - sampleLabel + label
    }
}

/// Every shape a slide caption's label takes, laid out hidden to measure, so the strip knows a
/// caption's width before any slide on it takes that shape, as the tenth slide's "Slide 10" or a
/// panorama's first "Slides 9–10" do. A card widening for a caption measured as the strip scrolls to
/// it leaves the scroll short of it, since the scroll view doesn't follow the card.
struct CaptionLabelWidths: View {
    /// Each label's width, by `slidesNameShape`.
    @Binding var widths: [String: CGFloat]

    /// One of each shape, from a single slide to a panorama, as far as a hundred slides.
    static let shapes = [1...1, 10...10, 100...100, 1...2, 9...10, 10...11, 99...100, 100...101].map(\.slidesNameShape)

    var body: some View {
        ZStack {
            ForEach(Self.shapes, id: \.self) { shape in
                Text(shape)
                    .monospacedDigit()
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                        if widths[shape] != width {
                            widths[shape] = width
                        }
                    }
            }
        }
        .font(SlideCard.captionFont)
        .hidden()
        .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var widths: [String: CGFloat] = [:]
    VStack(alignment: .leading) {
        CaptionLabelWidths(widths: $widths)
        ForEach(CaptionLabelWidths.shapes, id: \.self) { shape in
            Text("\(shape): \(widths[shape] ?? 0, format: .number.precision(.fractionLength(1)))")
        }
    }
    .padding()
}
