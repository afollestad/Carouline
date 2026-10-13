//
//  LayerKindTile.swift
//  Swipeset
//

import SwiftUI

/// A kind of layer to add, as a tile like the new project sheet's.
struct LayerKindTile: View {
    let kind: LayerKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.tint.opacity(0.18))
                    .strokeBorder(.tint, lineWidth: 2)
                    .overlay {
                        illustration
                            .foregroundStyle(.tint)
                    }
                    .frame(width: 72, height: 72)
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
                Text(kind.name)
                    .font(.headline)
                Text(kind.summary)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            // A plain fill rather than glass, which the sheet's own glass already is.
            .background(.fill.quaternary, in: .rect(cornerRadius: 16))
            .contentShape(.rect(cornerRadius: 16))
            .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kind.name)
        .accessibilityHint(kind.summary)
    }

    @ViewBuilder
    private var illustration: some View {
        switch kind {
        case .text:
            Text("Aa")
                .font(.system(size: 30, weight: .semibold, design: .serif))
        case .image:
            Image(systemName: kind.systemImage)
                .font(.system(size: 28, weight: .medium))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(LayerKind.allCases, id: \.self) { kind in
            LayerKindTile(kind: kind) {}
        }
    }
    .padding()
    .tint(.accentColor)
}
