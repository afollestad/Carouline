## Sheets

- Count every popover's content with `countsAsPopover()`, as `ConfirmationPopover` and `CaptionPopover` do, and open a popover from a button through `shownPopovers.whenGone`. SwiftUI cancels a popover asked for while another is still closing, as one is for a moment after it looks gone, so its button seems to need a second tap.
