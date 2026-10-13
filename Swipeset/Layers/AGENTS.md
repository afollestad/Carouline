## Layers

- Size and place layers only through `LayerGeometry`, and draw text only through `LayerRenderer.drawText`, which the screen's `SlideLayers` and the export share, so a layer looks the same on screen and in the export.
- Keep a gesture's per-frame placement and an editor's per-keystroke draft in `LayerSession`, and save each once, when it ends, since every `ProjectLibrary` save rewrites the whole project's JSON.
