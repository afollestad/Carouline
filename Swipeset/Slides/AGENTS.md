## Slides

- Keep `SlideStrip`'s layout size fixed while a layers sheet is open on a phone, and shrink its slides with `scaleEffect`, as `roomScale` does. The lazy stack drops the card that presents the sheet while laying out a new size, which closes the sheet.
- Keep drags and pinches on the selection in `SelectionGesture`, the strip's one high-priority gesture. A gesture on a cell or a layer would claim a pinch's first finger, and without the priority a short drag ends as a tap on whatever it crossed.
