//
//  PercentSlider.swift
//  Carouline
//

import SwiftUI

/// A slider for a share of something, from none to `maximum`, read out beside it as a percentage.
struct PercentSlider: View {
    let title: String
    @Binding var value: Double
    let maximum: Double
    /// Digits after the point, for a share fine enough to need them.
    var fractionLength = 1
    /// Whether the title shows before the slider, for a row with no section title to name it.
    var showsTitle = false
    /// The titles of the sliders stacked with this one, whose widest its title takes the width
    /// of, so their tracks line up.
    var alignedTitles: [String] = []
    /// Runs once the slider is let go, for a sheet that saves then.
    var onCommit: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Above the track at the largest sizes, since beside it they'd squeeze it to nothing.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    if showsTitle {
                        Text(title)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                    share
                }
                slider
            }
        } else {
            HStack(spacing: 12) {
                if showsTitle {
                    alignedTitle
                }
                slider
                share
            }
        }
    }

    private var alignedTitle: some View {
        ZStack(alignment: .leading) {
            ForEach(alignedTitles, id: \.self) { title in
                Text(title)
                    .hidden()
            }
            Text(title)
        }
        .accessibilityHidden(true)
    }

    private var slider: some View {
        Slider(value: $value, in: 0...maximum) {
            Text(title)
        } onEditingChanged: { isEditing in
            if !isEditing {
                onCommit()
            }
        }
        // The share itself, as shown, rather than how far along the slider it is.
        .accessibilityValue(Text(value, format: format))
    }

    /// As wide as the most reads, so it doesn't widen and narrow the track as the slider nears it.
    private var share: some View {
        ZStack(alignment: .trailing) {
            Text(maximum, format: format)
                .hidden()
            Text(value, format: format)
        }
        .monospacedDigit()
        .foregroundStyle(Color.primary)
        .frame(minWidth: 48, alignment: .trailing)
        .accessibilityHidden(true)
    }

    private var format: FloatingPointFormatStyle<Double>.Percent {
        .percent.precision(.fractionLength(fractionLength))
    }
}

#Preview {
    @Previewable @State var value = 0.02
    Form {
        PercentSlider(title: "Border", value: $value, maximum: 0.05)
    }
}
