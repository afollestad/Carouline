//
//  PercentSlider.swift
//  Swipeset
//

import SwiftUI

/// A slider for a share of something, from none to `maximum`, read out beside it as a percentage.
struct PercentSlider: View {
    let title: String
    @Binding var value: Double
    let maximum: Double
    /// Runs once the slider is let go, for a sheet that saves then.
    var onCommit: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            Slider(value: $value, in: 0...maximum) {
                Text(title)
            } onEditingChanged: { isEditing in
                if !isEditing {
                    onCommit()
                }
            }
            // The share itself, as shown, rather than how far along the slider it is.
            .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(1))))
            Text(value, format: .percent.precision(.fractionLength(1)))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(minWidth: 48, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    @Previewable @State var value = 0.02
    Form {
        PercentSlider(title: "Border", value: $value, maximum: 0.05)
    }
}
