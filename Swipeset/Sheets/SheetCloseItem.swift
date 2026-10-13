//
//  SheetCloseItem.swift
//  Swipeset
//

import SwiftUI

/// The X that closes a sheet, on the toolbar's glass. In the primary color, like the app's other
/// toolbar icons, rather than the accent the sheet tints its own controls with.
struct SheetCloseItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close, action: action)
                .tint(Color.primary)
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                Color.clear
                    .navigationTitle("Sheet")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        SheetCloseItem {}
                    }
            }
            .presentationDetents([.medium])
            .tint(.accentColor)
        }
}
