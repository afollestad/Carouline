# carouline.af.codes

This branch *is* the published site. GitHub Pages serves it from the repo root, so anything committed here goes live. There is no build step: `index.html`, `privacy.html`, the sheets in `styles/`, the scripts in `scripts/` and the assets in `images/` ship verbatim. Preview with a local static server (`python3 -m http.server`) rather than opening the file directly, so relative paths resolve the way they will in production.

## Look

- The colors come from the app, so keep them in step with it on `main`: `--accent` from `AccentColor`'s light and dark variants, the glow behind the page from `GlowBackdrop`'s corner colors, and the ribbon and title gradient from the icon's layers in `AppIcon.icon`.
- The glow is `body::before`, fixed to the window like the app's backdrop behind its screens, so the body has no background of its own and the canvas color is `html`'s.
- The hero's ribbon is the icon's mint band, drawn for the page and stretched to the window behind the phone. Section labels, the GitHub button and the scroll-to-top button are glass, like the app's floating chrome.

## Theming

`styles/index-light.css` and `styles/index-dark.css` hold the color tokens and the glow, and `styles/index-common.css` holds everything theme-independent. Both theme sheets ship on every load, media-scoped to `prefers-color-scheme`, so with no override the browser follows the OS on its own, including live appearance changes, with no JavaScript involved.

`scripts/dark-mode.js` only steps in when the toggle stores an override. It flips `media` to `all` or `not all` on the sheets and on every `<picture>` source with a `data-theme`, and sets both `theme-color` metas to the override's color. Anything else that varies by theme follows that pattern: ship both variants, media-scope them, and let the script flip them. Don't swap `src` from script or hide a duplicate with `display`, since a hidden `<img>` still downloads and a script-set `src` leaves the page unthemed without JavaScript.

## Images

Encode screenshots as lossless WebP (`cwebp -lossless -z 9`), since lossy ringing shows around UI text. Each `<img>` repeats its size in `width` and `height`, and the frame's `aspect-ratio` matches, so update both when a capture's size changes.

### Screenshots

- Capture them on `main` with `./scripts/screenshots.sh -b -o <dir>` and again with `--dark`. Both runs show the demo projects, so the light and dark sets match and one `alt` describes either.
- iPhone shots come from iPhone 18 Pro, halved from 1206x2622 to 603x1311: `iphone-project` is `2-project`, `iphone-new-project` is `6-new-project`, `iphone-panorama` is `4-panorama` and `iphone-export` is `5-export`. `ipad-layers` is the iPad Pro 13-inch's `3-layers`, halved to 1032x1376. Each ships as `-light` and `-dark`.
- The captures are full screen with square corners. `.device` frames draw the bezel and round the screen, and `.phone::after` draws the Dynamic Island the captures leave room for. Each frame's geometry is a share of its screen width `--w`, measured for iPhone 18 Pro and iPad Pro 13-inch, so a capture from another device needs its own numbers.

### Icons

- `images/app-icon-light.png` and `-dark.png` are Icon Composer renders of `Carouline/AppIcon.icon` on `main`, with the plate and corner mask already in them, scaled to 256x256: `"/Applications/Icon Composer.app/Contents/Executables/ictool" Carouline/AppIcon.icon --export-image --output-file out.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`, with `--rendition Dark` for the dark one.
- `favicon.png` is the light render at 96x96, in both appearances. Safari draws its own backdrop behind a favicon too dark for its tab bar, and reads icon links once at load, so a themed favicon could neither look right nor follow the toggle.
- `apple-touch-icon.png` is the light render at 180x180, flattened onto `#F9F9FB`, the middle of its plate's gradient. iOS masks it itself and fills transparent corners with black.

### Link preview

`images/og-image.png` is 1200x630 on the dark glow over the dark theme's `#0f0a1f`: the dark icon, the name in the dark title gradient and a one-line tagline on the left, and the dark `iphone-project` in its frame on the right, cut off by the bottom edge, with the ribbon redrawn to run under the text and rise behind the phone. It's rendered from a scratch page that links `styles/index-common.css` for the frame, with headless Chrome: `--headless=new --force-dark-mode --window-size=1200,630 --screenshot`. A preview can't know the reader's theme, and composites transparency unpredictably. Re-export it whenever the hero screenshot changes, and keep it a PNG, since crawler support for WebP is patchy.

## Privacy policy

- `privacy.html` is the app's privacy policy, moved here verbatim from af.codes. Its old address there, `privacypolicy/carouline.html`, redirects here with JavaScript so links to it keep working. Keep this path.
- Change the policy's text only with the app's data handling, and its effective date with it.
- The page shares the home page's sheets and toggle: `styles/index-common.css` for the base and footer, the theme sheets for every color, and `styles/privacy.css` for its own layout. The home page's heading styles are scoped to `.hero-copy` and `.section-feature` so they don't reach it.

## Content

- Keep the App Store badge Apple's artwork, unaltered, and at least 40px tall, as its guidelines ask.
