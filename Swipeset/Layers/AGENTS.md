## Layers

- Size and place layers only through `LayerGeometry`, and draw text only through `LayerRenderer.drawText`, which the screen's `SlideLayers` and the export share, so a layer looks the same on screen and in the export.
- Keep a gesture's per-frame placement in `LayerSession` and save it once, when the gesture ends, since every `ProjectLibrary` save rewrites the whole project's JSON.
