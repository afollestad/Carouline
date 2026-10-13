## Layers

- Size and place layers only through `LayerGeometry`, draw text only through `LayerRenderer.drawText`, and outline a transparent picture only through `LayerImageEffects`, which the screen and the export share, so a layer looks the same in each.
- Keep a gesture's per-frame placement and an editor's per-keystroke draft in `LayerSession`, and save each once, when it ends, since every `ProjectLibrary` save rewrites the whole project's JSON.
- Read a `List` row's cell bounds through UIKit, as `RowBoundsReader` does. SwiftUI's geometry stops at the row's content: `bounds(of:)` gives `nil` for a named coordinate space or `.scrollView` there, and `containerRelativeFrame` measures only the cell's content view, which edit mode's controls narrow.
- Offer only the typing detent while a text layer is typed, as `LayersSheet.detents` does. The keyboard grows a sheet to the largest detent it offers, whichever is selected, covering the slide being typed on.
- Never switch a view's structure on state its own subtree reports up, such as `CellPhoto`'s `isMissing`, since rebuilding the subtree resets the state that reported it. Vary only modifier values with it, or overlay what it shows, as `PictureLayerView` does.
