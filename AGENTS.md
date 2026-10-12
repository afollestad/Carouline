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
- Source folders are synchronized groups, so new files under `Swipeset/` or `SwipesetTests/` join their targets without touching `project.pbxproj`. Info.plist keys, usage descriptions included, are `INFOPLIST_KEY_*` build settings; there is no Info.plist file.
- First-time setup: `./scripts/setup.sh` installs `swiftlint`, `xcsift` and `axe` and a pre-commit hook that lints.
- Build, run, test, lint and snapshot through `scripts/`, not raw `xcodebuild`, `simctl launch` or `swiftlint`. They pin the simulator, test locale and DerivedData path (`.build/xcode`) that results and baselines depend on.
- Build: `./scripts/build.sh`. Run in the simulator: `./scripts/run.sh -b` builds first, while bare `run.sh` relaunches the last build (set `SIMULATOR` to pick another device).
- Tests use Swift Testing: `./scripts/test.sh`, or pass identifiers such as `SwipesetTests/SwipesetAppTests`. It runs `SnapshotTests` on iPhone 18 Pro, `WideSnapshotTests` on iPad mini (A17 Pro), and everything else on `SIMULATOR`'s.
- Snapshots: `./scripts/snapshots.sh verify`, or `record` to rewrite baselines and then verify them. `SwipesetTests/Snapshots/AGENTS.md` covers both.
- Lint: `./scripts/lint.sh` from the repo root. SwiftLint runs in strict mode and Swift warnings are errors, so both fail on any warning.
- Keep `-parallel-testing-enabled NO` and `-collect-test-diagnostics never` in the test scripts. Parallel testing runs on clones that shut the original simulator down, and failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.

## Verifying UI

- Every visible change is checked in the simulator, not just compiled: launch it with `./scripts/run.sh -b` and capture with `xcrun simctl io <udid> screenshot`.
- Every visible change also runs `./scripts/snapshots.sh verify`. When the change is intended, `record` the affected baselines and look at the new images.
- `simctl` cannot tap or drag, so use `axe touch --down --up --delay 0.1`, `axe drag` and `axe describe-ui` with `--udid`, which reach the simulator without the host's cursor. Never post host mouse events, which take over the user's.
- Restore every temporary patch before finishing. Keep a backup copy and confirm with `git diff`.

## Design rules

- Floating chrome is Liquid Glass: toolbar items, partial-height sheets, and the buttons over slides. Don't put glass on content inside a glass sheet or popover, which reads as glass on glass.
- Keep `AccentColor` the icon's violet. Hold the light variant to 4.5:1 against white, and the dark one to 4.5:1 against the dark system background and 3:1 under a prominent button's white label.
- Hide decorative shapes from accessibility. Every control needs a label, and an icon-only button a hint when its action isn't obvious.

## Code conventions

- Group files by theme in folders under `Swipeset/`, mirrored in `SwipesetTests/`. Put a new file in the theme it serves, or start a theme when none fits.
- Keep each view file to one screen or overlay.
- Every view has a `#Preview`. Use `@Previewable @State` for bindings.
- Doc comments explain why a constant has its value, not what the code does.
- Default isolation is `MainActor`: mark models that cross actors `nonisolated`, and heavy `async` work `@concurrent`, since approachable concurrency runs a `nonisolated async` function on its caller's actor.
- Unit tests cover the model and snapshots cover screens.
- Write test files into a `TemporaryDirectory` held by the suite, which removes it after each test, since the simulator doesn't empty a test host's `tmp` between runs. Await any task that outlives the call under test, or it writes the directory back after removal.
