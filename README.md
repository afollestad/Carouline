# Carouline

Carouline is a native iOS app for photo carousels. Pick a slide shape, lay out each slide with one to four photos from the camera or your library, or cut one wide photo across several slides as a panorama, then save the set to Photos or share it to any app that takes several images at once.

## Development

```sh
./scripts/setup.sh             # Install SwiftLint, xcsift and AXe, and a lint pre-commit hook
./scripts/build.sh             # Build for the iOS Simulator (--device <udid> for an iPhone or iPad)
./scripts/run.sh -b            # Build, install, and launch on a reachable iPhone or iPad, else the simulator (-s for the simulator; -d <name or UDID> for a device; omit -b to relaunch the last build; pass launch arguments after --)
./scripts/test.sh              # Run unit and snapshot tests
./scripts/snapshots.sh verify  # Compare snapshots against their baselines (record to update them)
./scripts/lint.sh              # Run SwiftLint
```

## License

Carouline is licensed under the [GNU General Public License v3.0](LICENSE.md).
