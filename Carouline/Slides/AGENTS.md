## Slides

### Strip layout and scrolling

- Keep `SlideStrip`'s layout size fixed while a layers sheet is open, and shrink and move its slides with `scaleEffect` and `offset`, as `RoomFit` does. Slides laid out at a new size decode their photos again for it, on every frame the sheet moves.
- Lay the strip out in an `HStack`, never a lazy stack, and build only the slides near its middle, as `builtSlides` does, with a `SlidePlaceholder` for the rest. A lazy stack guesses the widths of slides it hasn't built, so they sit off the stops the strip scrolls by.
- Shape anything beside or in place of a slide in the strip like a card, padding it by `captionSpace` below as the add button and `SlidePlaceholder` are, since the strip centers each card whole, caption included.
- Clip the strip and its content shape where iPhone Duo's column of bar buttons starts, with `TrailingClip`, since a clip alone still lets taps reach the slides it hides. Its scroll view reaches under the column even when padded clear of the safe area there with `ignoresSafeArea`, and no scroll edge effect softens what's under it.
- Scroll the strip by offset through `StripScrolling`, never `scrollPosition(id:)`, and keep what sits on a panorama in view with `followsStripMiddle`'s `offset`, never a `visualEffect`. A scroll view finds the item whose middle is nearest its own, the slide beside a panorama wider than the screen, and a popover, tour anchor or tap stays where layout put it under a visual effect.

### Gestures and presentation

- Keep drags and pinches on the selection in `SelectionGesture`, over the whole strip, since a gesture on a cell or a layer would claim a pinch's first finger. Its `TouchTracking` claims the touches once they move the selection, so a short drag doesn't end as a tap on whatever it crossed.
- Move the selection by the fingers `TouchTracking` reports to `SelectionTouches`, since SwiftUI's gesture values end or reset as a finger lifts or lands. Take `MagnifyGesture` and `RotateGesture` values only for a trackpad's pinch, which reports no fingers.
- Never put a high-priority `DragGesture` or a `SpatialEventGesture` over the strip. The first holds its scrolling back for every drag, even off the selection, and under the second a tap on a menu inside the strip also reaches its background tap.
- Take drops on the slide card, finding the cell from the drop's location, since a layer over a cell would otherwise take a drop meant for it.
- On a compact width, present what has detents as a sheet through `ProjectPresenting.sheetItem`, never as a popover adapted to one. A popover shown as a sheet never writes a dragged-to detent back to `presentationDetents`' selection, so the next time anything applies the selection again, the last one set comes back.
- Aim anything at a toolbar item from its bar item's `frame(in:)`, read from the screen's navigation item as `ShareButtonReader` does, since SwiftUI measures a toolbar item in a space of its own and hosts no representable in it. Never assume where the bar puts it: iPhone Duo stacks the bar's buttons down the screen's trailing edge, under the status bar.
- Open a slide caption's choices in a `CaptionPopover`, never a `Menu`. A menu's rows lie over the caption's other buttons, which take taps meant for the rows.
