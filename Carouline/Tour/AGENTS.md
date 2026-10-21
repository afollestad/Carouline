## Tour

- Keep each tip's type name, which TipKit remembers it by, so renaming one shows it again on installs that finished it. Add a step as a new type.
- Show the tour's tips inline with `TipView`, never `popoverTip`. A popover tip still up as a sheet opens leaves the screen unable to present a popover again, and TipKit shows none from a toolbar item.
- Point a tip at a view elsewhere by marking the view with `tourTarget(_:)`, then drawing `TourAnchor.standIn(at:)` beside the `TipView` in one `ZStack`, at the bounds `overlayPreferenceValue` reads. TipKit lines an arrow up only with an anchor placed that way, so a `.tipAnchor` on the view itself, as on a caption's glass button, lands the arrow out of place.
- Build every anchor with `ProjectTour.anchor(_:)`, which keys it by the tour's visit. TipKit keeps anchors by ID in one store, and another window on the same project shows the same tip.
- Reach the tour with `-DebugFirstLaunch YES`, which gives it a fresh datastore. Don't expect it under `-DebugSampleProjects` or `-DebugDemoProjects`, which turn it off.
