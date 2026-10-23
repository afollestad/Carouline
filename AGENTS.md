# AGENTS.md

Guidance for AI agents working in this repo. `README.md` says what the app is.

## About this file

- Keep only durable, non-obvious rules: things an agent cannot derive from the code, git history, or `README.md` and would otherwise get wrong.
- Do not record file inventories, task history, in-progress work, or personal tooling preferences. Those live in each agent's global config.
- Keep every `AGENTS.md` slim: one rule per bullet, in the imperative, at most two sentences. Add the reason inline only when it isn't obvious.
- Sections are fixed and stay in the order below. A section holds at most ten rules; when it outgrows that, move the detail to a file under `docs/agents/` and leave a one-line pointer here.
- Rules that apply to a single directory go in an `AGENTS.md` inside that directory, not here. Before editing files in a folder, read its `AGENTS.md` if it has one, since some agents load only the root file.
- Whenever you create an `AGENTS.md`, create a `CLAUDE.md` symlink beside it in the same change (`ln -s AGENTS.md CLAUDE.md`), so every agent loads it.
- List both files in their target's `membershipExceptions` in `project.pbxproj`, or the synchronized group copies them into the bundle, where same-named files collide. Xcode drops an exception whose path no longer exists when it next saves the project, so recheck after moving either.
- Keep this file under 120 lines. Delete rules that stop being true rather than hedging them.

## Build and test

- Xcode 27 project with an iOS 26 deployment target, so gate iOS 27 APIs with `#available`. Use iOS 26 APIs such as Liquid Glass, scroll edge effects, and `navigationSubtitle` freely.
- Don't register new files under `Carouline/` or `CaroulineTests/` in `project.pbxproj`, since source folders are synchronized groups that add them to their targets.
- Set Info.plist keys, usage descriptions included, as `INFOPLIST_KEY_*` build settings; there is no Info.plist file.
- First-time setup: `./scripts/setup.sh` installs `swiftlint`, `xcsift`, `axe` and `duoctl`, a pre-commit hook that lints, and any missing simulators the scripts run on.
- Build, run, test, lint and snapshot through `scripts/`, not raw `xcodebuild`, `simctl launch` or `swiftlint`. They pin the simulator, test locale and DerivedData path (`.build/xcode`) that results and baselines depend on.
- Build: `./scripts/build.sh`. Run: `./scripts/run.sh -b` builds first, while bare `run.sh` relaunches the last build; it prefers a reachable iPhone or iPad, so pass `-s` (or set `SIMULATOR` to pick another device) for the simulator, or `-d <name or UDID>` for any device.
- Tests use Swift Testing: `./scripts/test.sh`, or pass identifiers such as `CaroulineTests/CaroulineAppTests`. It runs `SnapshotTests` on iPhone 18 Pro, `WideSnapshotTests` on iPad mini (A17 Pro), and everything else on `SIMULATOR`'s.
- Snapshots: `./scripts/snapshots.sh verify`, or `record` to rewrite baselines and then verify them. `CaroulineTests/Snapshots/AGENTS.md` covers both.
- Lint: `./scripts/lint.sh` from the repo root. SwiftLint runs in strict mode and Swift warnings are errors, so both fail on any warning.
- Keep `-parallel-testing-enabled NO` and `-collect-test-diagnostics never` in the test scripts. Parallel testing runs on clones that shut the original simulator down, and failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.

## Verifying UI

- Every visible change is checked in the simulator, not just compiled: launch it with `./scripts/run.sh -b -s` and capture with `xcrun simctl io <udid> screenshot`. On iPhone Duo, fold or unfold it with `duoctl close` or `duoctl open`, rebooting the simulator if that times out, and pass `--display=primary` (outer) or `--display=primary-1` (inner), since the screen that's off captures black.
- Every visible change also runs `./scripts/snapshots.sh verify`. When the change is intended, `record` the affected baselines and look at the new images.
- Reach other states with debug launch arguments after `--`, e.g. `./scripts/run.sh -b -s -- -DebugSampleProjects YES -DebugSheet newProject`. `DebugSettings` documents each one; open sheets through `-DebugSheet`, since a presentation on the first frame doesn't render.
- `simctl` cannot tap or drag, so use `axe tap`, `axe drag` and `axe describe-ui` with `--udid`, which reach the simulator without the host's cursor. Never post host mouse events, which take over the user's.
- Tap with `axe tap --tap-style physical`, since the default style can miss buttons in sheets.
- Long-press with an `axe drag` that moves a point over `--duration 1.5`, since `axe touch` can fail with "could not establish simulator input", and hold then drag with few `--steps` over a long `--duration`, so its first move comes after the hold. Move the zoom slider by dragging its thumb with `axe drag` too, since `axe slider` can't.
- Never `axe drag` an iPad app's corner to resize its window, since input to a windowed app stops landing; reach other widths on another simulator. If every input fails, shut the simulator down with `xcrun simctl shutdown <udid>`, and `run.sh -s` boots it again.
- The simulator has no camera, so its cells go straight to the photo picker, whose library already holds sample photos; add more with `xcrun simctl addmedia <udid> <files>`.
- Judge launch and loading speed with the app opened from a device's Home Screen, or run with the scheme's "Debug executable" off. Xcode's debugger pauses the app for each of the 2,000-odd libraries it loads, adding seconds at launch and on first use of image decoding, haptics and the camera.
- Restore every temporary patch before finishing. Keep a backup copy and confirm with `git diff`.

## Design rules

- Floating chrome is Liquid Glass: toolbar items, partial-height sheets, project rows, slide captions, the buttons over slides, and the strip's empty cells, whose slide background is left out under them. Don't put glass on content inside a glass sheet or popover, which reads as glass on glass, except a button matching the toolbar's glass buttons, as the New Project sheet's Edit and Done do.
- Screens sit on `GlowBackdrop`, or `SlideBackdrop` on the project screen, never a flat system background, so their glass has color to frost. A plain list draws section headers and footers on an opaque band over it, so put notes in clear rows.
- Confirm with `confirmationPopover`, never `confirmationDialog`. The dialog runs its action only once it has finished closing, about half a second after the tap, or over a second from a title bar button, well after it looks gone.
- Glass over a slide takes its color scheme from what it sits on, not the system's, so it stays legible on a white slide in dark mode: the slide's background, a missing photo's placeholder, or for an empty cell's glass, the screen behind the slide.
- Give text in glass sheets and popovers `Color.primary`, not gray: on iPad the popovers float over the slides, and a bright photo through the glass washes gray text out.
- Draw the accent solid in glass sheets and popovers, with white on it, and give their icon-only toolbar buttons and menu icons a tint of their own, `Color.primary` as `SheetCloseItem` does or red for a destructive item. A faint tint of the accent, or an accent glyph, washes out on the glass, and a menu's icons take the sheet's accent otherwise.
- Keep `AccentColor` the icon's violet. Hold the light variant to 4.5:1 against white, and the dark one to 4.5:1 against the dark system background and 3:1 under a prominent button's white label.
- Give every scroll view under a navigation bar the soft top scroll edge effect, as `SlideStrip` and `LayerPage` do; the default draws a solid band with a hairline under the bar, cutting off what scrolls under it.
- Cap the slide strip and the selection bars at `accessibility1`, since slides leave fixed room for their captions and buttons. Sheets and the projects list stay uncapped.
- Hide decorative shapes from accessibility. Every control needs a label, and an icon-only button a hint when its action isn't obvious.

## Code conventions

- Group files by theme in folders under `Carouline/`, mirrored in `CaroulineTests/`. Put a new file in the theme it serves, or start a theme when none fits.
- Keep each view file to one screen or overlay.
- Every view has a `#Preview`. Use `@Previewable @State` for bindings.
- Doc comments explain why a constant has its value, not what the code does.
- Pad a horizontal scroll view's content rather than using `contentMargins`, which stop view-aligned scrolling from snapping and center `scrollPosition`'s anchor between the margins. To rest targets in the middle, snap with a `ScrollTargetBehavior` of their stops, as `StripSnapping` does, since `.viewAligned` rests leading edges on the screen's whatever its anchor.
- Count and number the carousel with `Project.carouselSlideCount` and `slideNumbers`, never `slides.count` or indexes, since a panorama is one slide that posts as several.
- Default isolation is `MainActor`: mark models that cross actors `nonisolated`, and heavy `async` work `@concurrent`, since approachable concurrency runs a `nonisolated async` function on its caller's actor.
- Start a repeating animation with an explicit `withAnimation`, as `LoadingPulse` does, which `assertScreenSnapshot()`'s `transaction` holds still. An implicit or scoped `.animation` sets its own and keeps moving there, so the baseline flakes.
- Unit tests cover the model and snapshots cover screens.
- Write test files into a `TemporaryDirectory` held by the suite, which removes it after each test, since the simulator doesn't empty a test host's `tmp` between runs. Await any task that outlives the call under test, or it writes the directory back after removal.
