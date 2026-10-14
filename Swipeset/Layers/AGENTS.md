## Layers

- Size and place layers only through `LayerGeometry`, draw text only through `LayerRenderer.drawText`, and outline a transparent picture only through `LayerImageEffects`, which the screen and the export share, so a layer looks the same in each.
- Keep a gesture's per-frame placement and an editor's per-keystroke draft in `LayerSession`, and save each once, when it ends, since every `ProjectLibrary` save rewrites the whole project's JSON.
- Read a `List` row's cell bounds through UIKit, as `RowBoundsReader` does. SwiftUI's geometry stops at the row's content: `bounds(of:)` gives `nil` for a named coordinate space or `.scrollView` there, and `containerRelativeFrame` measures only the cell's content view, which edit mode's controls narrow.
- Offer only the typing detent while a text layer is typed, as `LayersSheet.detents` does. The keyboard grows a sheet to the largest detent it offers, whichever is selected, covering the slide being typed on.
- End typing from a Done in the title bar, as `TextLayerEditor` does, never a keyboard toolbar. Its floating bar covers the bottom of the typing detent, so the field scrolls up under the title.
- Never switch a view's structure on state its own subtree reports up, such as `CellPhoto`'s `isMissing`, since rebuilding the subtree resets the state that reported it. Vary only modifier values with it, or overlay what it shows, as `PictureLayerView` does.
- Make room for a phone's layers sheet only once it rests at the selected height, measured on screen, as `LayersSheet.settle(at:)` does. A floating sheet covers a little less than its detent, and a drag paused partway rests at none.
- Keep one view per layer in `SlideLayers`, whatever's selected or drafted, as `LayerSlot` does, and read the draft and the live placement inside it. Switching its structure rebuilds the layers, resetting each picture's state and running its tasks again.
