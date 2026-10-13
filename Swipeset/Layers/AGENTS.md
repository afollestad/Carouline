## Layers

- Size and place layers only through `LayerGeometry`, draw text only through `LayerRenderer.drawText`, and outline a transparent picture only through `LayerImageEffects`, which the screen and the export share, so a layer looks the same in each.
- Keep a gesture's per-frame placement and an editor's per-keystroke draft in `LayerSession`, and save each once, when it ends, since every `ProjectLibrary` save rewrites the whole project's JSON.
