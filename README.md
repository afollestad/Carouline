<p align="center">
  <picture>
    <source srcset="docs/images/app-icon-dark.png" media="(prefers-color-scheme: dark)">
    <img src="docs/images/app-icon-light.png" alt="" width="96" height="96">
  </picture>
</p>

<h1 align="center">Carouline</h1>

<p align="center">A native iOS app for photo carousels.</p>

<p align="center">
  <a href="https://apps.apple.com/us/app/carouline/id6822795714"><img src="docs/assets/app-store-badge.svg" alt="Download on the App Store"></a>
</p>

Pick a slide shape or your own ratio, gather photos into a tray, and lay out each slide with one to four photos, or cut one wide photo across several slides as a panorama. Then save the set to Photos or share it to any app that takes several images at once.

## Development

```sh
./scripts/setup.sh             # Install tools, a lint pre-commit hook, and the simulators the scripts use
./scripts/build.sh             # Build for the iOS Simulator
./scripts/run.sh -b            # Build and launch on a reachable iPhone or iPad, else the simulator (-s for the simulator)
./scripts/test.sh              # Run unit and snapshot tests
./scripts/snapshots.sh verify  # Compare snapshots against their baselines (record to update them)
./scripts/lint.sh              # Run SwiftLint
./scripts/screenshots.sh -b    # Build, then capture App Store screenshots (--dark for dark mode)
```

## License

Carouline is licensed under the [GNU General Public License v3.0](LICENSE.md).
