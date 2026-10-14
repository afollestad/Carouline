## Slides

- Keep `SlideStrip`'s layout size fixed while a layers sheet is open on a phone, and shrink its slides with `scaleEffect`, as `roomScale` does. The lazy stack drops the card being edited while laying out a new size, and rebuilds it.
- Keep drags and pinches on the selection in `SelectionGesture`, the strip's one high-priority gesture. A gesture on a cell or a layer would claim a pinch's first finger, and without the priority a short drag ends as a tap on whatever it crossed.
- On a compact width, present what has detents as a sheet through `ProjectScreen.sheetItem`, never as a popover adapted to one. A popover shown as a sheet never writes a dragged-to detent back to `presentationDetents`' selection, so the next time anything applies the selection again, the last one set comes back.
