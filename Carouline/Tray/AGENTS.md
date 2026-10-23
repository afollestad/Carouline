## Tray

- Take taps on views under `TrayPressGesture` through an `onTapGesture`, as `TrayThumbnailStyle` does, never a `Button`'s own tracking. A button keeps tracking the finger once the press begins, so lifting after a hold would also tap whatever the finger landed on.
