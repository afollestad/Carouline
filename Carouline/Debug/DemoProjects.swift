//
//  DemoProjects.swift
//  Carouline
//

#if DEBUG
import Foundation

/// Finished-looking projects for App Store screenshots: one of every shape, every cell filled,
/// with styled slides and layers. Unlike `SampleProjects`, nothing is left empty or missing for
/// development. Their photos are `SampleImages`, and `SampleStore` writes them out.
enum DemoProjects {
    /// Most recently changed first, which is the order the list shows them in.
    static var all: [Project] {
        [lisbon, bigSur, brunch, collection, trailRun, wedding, studio, kyoto, lemonTart]
    }

    /// The first in the list, which screenshots open, so it shows off the most: five layouts,
    /// one a panorama, under titles, a sticker and a blur.
    private static var lisbon: Project {
        Project(
            name: "Lisbon Weekend",
            aspectRatio: .portrait,
            slides: [
                Slide(
                    layout: .single,
                    cells: [photo(101, .sunset, 1600, 2000, fromTray: 201)],
                    layers: [
                        text("Lisbon", font: .didot, centerY: 0.16, scale: 1.6),
                        text("A long weekend", font: .avenirNext, centerY: 0.25, scale: 0.55)
                    ]
                ),
                Slide(
                    layout: .twoColumns,
                    cells: [
                        photo(102, .ember, 1200, 1600, fromTray: 202),
                        photo(103, .sky, 1200, 1600, crop: ImageCrop(scale: 1.3, centerX: 0.6, centerY: 0.6))
                    ],
                    style: SlideStyle(spacing: 0.02, border: 0.03, background: cream)
                ),
                Slide(
                    layout: .grid,
                    cells: [
                        photo(104, .lagoon, 1600, 1600, fromTray: 204),
                        photo(105, .dusk, 1600, 1600),
                        photo(106, .sunset, 1600, 1200),
                        photo(107, .ember, 1200, 1600)
                    ],
                    layers: [
                        sticker(108, .ember, centerX: 0.8, centerY: 0.2, scale: 0.5),
                        text("Tram 28", font: .marker, color: yellow, isHighlighted: true, centerY: 0.5, scale: 0.8, rotation: -0.06)
                    ]
                ),
                // As wide as three portrait slides, so the panorama shows all of it.
                Slide(
                    layout: .panorama,
                    span: 3,
                    cells: [photo(109, .dusk, 3840, 1600, fromTray: 203)],
                    layers: [text("Alfama at dusk", font: .script, centerX: 1.5, centerY: 0.2, scale: 2.2)]
                ),
                Slide(
                    layout: .oneTopTwoBottom,
                    cells: [photo(110, .sky, 1600, 1067, fromTray: 205), photo(111, .lagoon, 1200, 1600), photo(112, .sunset, 1200, 1600)]
                ),
                Slide(
                    layout: .single,
                    cells: [photo(113, .ember, 1600, 2000)],
                    layers: [text("Até já, Lisboa", font: .handwriting, centerY: 0.5, scale: 1.1)],
                    blur: 0.02
                )
            ],
            // Most of the photos gathered for it on slides, and a few still to place.
            tray: [
                trayPhoto(201, .sunset, 1600, 2000),
                trayPhoto(202, .ember, 1200, 1600),
                trayPhoto(206, .sky, 1600, 1200),
                trayPhoto(203, .dusk, 3840, 1600),
                trayPhoto(204, .lagoon, 1600, 1600),
                trayPhoto(207, .dusk, 1200, 1600),
                trayPhoto(205, .sky, 1600, 1067),
                trayPhoto(208, .dusk, 1600, 1067)
            ],
            createdAt: date(daysAgo: 0.1)
        )
    }

    /// A landscape road trip that opens on a long panorama.
    private static var bigSur: Project {
        Project(
            name: "Big Sur Drive",
            aspectRatio: .landscape,
            slides: [
                // As wide as four landscape slides.
                Slide(
                    layout: .panorama,
                    span: 4,
                    cells: [photo(201, .sky, 6106, 800)],
                    layers: [
                        text("Big Sur", font: .futura, centerY: 0.32, scale: 1.4),
                        text("Highway 1 →", font: .rounded, color: violet, isHighlighted: true, centerX: 1, centerY: 0.75, scale: 0.7)
                    ]
                ),
                Slide(
                    layout: .threeColumns,
                    cells: [photo(202, .ember, 1067, 1600), photo(203, .sunset, 1067, 1600), photo(204, .dusk, 1067, 1600)],
                    style: SlideStyle(spacing: 0.015, border: 0.015, background: .black)
                ),
                Slide(layout: .twoColumns, cells: [photo(205, .lagoon, 1200, 1600), photo(206, .sky, 1200, 1600)]),
                Slide(
                    layout: .single,
                    cells: [photo(207, .sunset, 1600, 838)],
                    layers: [text("Worth the detour", font: .typewriter, centerY: 0.82, scale: 0.75)]
                )
            ],
            createdAt: date(daysAgo: 2)
        )
    }

    private static var brunch: Project {
        Project(
            name: "Sunday Brunch",
            aspectRatio: .square,
            slides: [
                Slide(
                    layout: .grid,
                    cells: [
                        photo(301, .ember, 1600, 1600),
                        photo(302, .lagoon, 1600, 1600),
                        photo(303, .dusk, 1600, 1600),
                        photo(304, .sunset, 1600, 1600)
                    ],
                    layers: [text("Brunch Club", font: .script, color: .white, isHighlighted: true, rotation: -0.06)],
                    style: SlideStyle(spacing: 0.025, border: 0.04, background: .white)
                ),
                Slide(
                    layout: .oneLeftTwoRight,
                    cells: [photo(305, .sky, 1200, 1600), photo(306, .ember, 1600, 1200), photo(307, .lagoon, 1600, 1200)],
                    style: SlideStyle(spacing: 0.02, border: 0.04, background: butter)
                ),
                Slide(
                    layout: .single,
                    cells: [photo(308, .dusk, 1600, 1600)],
                    layers: [
                        sticker(309, .ember, centerX: 0.22, centerY: 0.22, scale: 0.55),
                        text("Same time next week?", font: .rounded, color: pink, isHighlighted: true, centerY: 0.8, scale: 0.7)
                    ]
                )
            ],
            createdAt: date(daysAgo: 4)
        )
    }

    /// Product shots on black, framed by a wide border.
    private static var collection: Project {
        let style = SlideStyle(spacing: 0.02, border: 0.05, background: charcoal)
        return Project(
            name: "New Collection",
            aspectRatio: .tallPortrait,
            slides: [
                Slide(
                    layout: .single,
                    cells: [photo(401, .dusk, 1500, 2000, crop: ImageCrop(scale: 1.2, centerX: 0.55, centerY: 0.55))],
                    layers: [
                        text("New Collection", font: .copperplate, centerY: 0.84, scale: 0.85),
                        text("Fall 2026", font: .didot, centerY: 0.91, scale: 0.55)
                    ],
                    style: style
                ),
                Slide(layout: .twoRows, cells: [photo(402, .sunset, 1600, 1067), photo(403, .sky, 1600, 1067)], style: style),
                Slide(
                    layout: .twoLeftOneRight,
                    cells: [photo(404, .lagoon, 1600, 1600), photo(405, .ember, 1200, 2000), photo(406, .dusk, 1600, 1600)],
                    style: style
                ),
                // A blurred photo as a backdrop for a framed print laid over it.
                Slide(
                    layout: .single,
                    cells: [photo(407, .sky, 1500, 2000)],
                    layers: [
                        framedPhoto(408, .sunset, centerY: 0.45, scale: 1.5, rotation: 0.05),
                        text("Shop the drop", font: .futura, centerY: 0.86, scale: 0.8)
                    ],
                    blur: 0.04,
                    style: style
                )
            ],
            createdAt: date(daysAgo: 7)
        )
    }

    private static var trailRun: Project {
        Project(
            name: "Trail Run",
            aspectRatio: .story,
            slides: [
                Slide(
                    layout: .threeRows,
                    cells: [photo(501, .lagoon, 1600, 1067), photo(502, .sky, 1600, 1067), photo(503, .ember, 1600, 1067)],
                    layers: [text("12 km", font: .marker, color: yellow, centerY: 0.5, scale: 1.8, rotation: -0.08)]
                ),
                Slide(
                    layout: .single,
                    cells: [photo(504, .sunset, 1125, 2000)],
                    layers: [
                        sticker(505, .sky, centerX: 0.72, centerY: 0.3, scale: 0.6),
                        text("New PB!", font: .rounded, color: orange, isHighlighted: true, centerY: 0.42, scale: 1.1, rotation: -0.05)
                    ]
                ),
                // As wide as two story slides.
                Slide(layout: .panorama, span: 2, cells: [photo(506, .lagoon, 2250, 2000)])
            ],
            createdAt: date(daysAgo: 10)
        )
    }

    private static var wedding: Project {
        let style = SlideStyle(spacing: 0.02, border: 0.03, background: blush)
        return Project(
            name: "Wedding Day",
            aspectRatio: .portrait,
            slides: [
                Slide(
                    layout: .single,
                    cells: [photo(601, .dusk, 1600, 2000)],
                    layers: [
                        text("Ana & Leo", font: .script, centerY: 0.2, scale: 1.7),
                        text("06 · 14 · 2026", font: .didot, centerY: 0.3, scale: 0.5)
                    ]
                ),
                Slide(
                    layout: .twoTopOneBottom,
                    cells: [photo(602, .sunset, 1200, 1600), photo(603, .ember, 1200, 1600), photo(604, .lagoon, 1600, 1067)],
                    style: style
                ),
                Slide(
                    layout: .grid,
                    cells: [
                        photo(605, .sky, 1600, 1600),
                        photo(606, .dusk, 1600, 1600),
                        photo(607, .sunset, 1600, 1600),
                        photo(608, .lagoon, 1600, 1600)
                    ],
                    style: style
                ),
                Slide(
                    layout: .single,
                    cells: [photo(609, .ember, 1600, 2000)],
                    layers: [framedPhoto(610, .dusk, centerY: 0.5, scale: 1.3, rotation: -0.06)]
                )
            ],
            createdAt: date(daysAgo: 15)
        )
    }

    private static var studio: Project {
        let style = SlideStyle(spacing: 0.015, border: 0.03, background: charcoal)
        return Project(
            name: "Studio Tour",
            aspectRatio: .square,
            slides: [
                Slide(
                    layout: .threeColumns,
                    cells: [photo(701, .sky, 1067, 1600), photo(702, .lagoon, 1067, 1600), photo(703, .dusk, 1067, 1600)],
                    layers: [text("Studio 04", font: .mono, color: .white, isHighlighted: true, centerY: 0.84, scale: 0.8)],
                    style: style
                ),
                Slide(layout: .twoRows, cells: [photo(704, .ember, 1600, 1067), photo(705, .sunset, 1600, 1067)], style: style)
            ],
            createdAt: date(daysAgo: 21)
        )
    }

    private static var kyoto: Project {
        Project(
            name: "Kyoto in Autumn",
            aspectRatio: .tallPortrait,
            slides: [
                Slide(
                    layout: .oneLeftTwoRight,
                    cells: [photo(801, .ember, 1200, 2000), photo(802, .sunset, 1600, 1200), photo(803, .dusk, 1600, 1200)],
                    layers: [text("Kyoto", font: .serif, centerY: 0.86, scale: 1.3)]
                ),
                // As wide as two tall portrait slides.
                Slide(layout: .panorama, span: 2, cells: [photo(804, .ember, 2400, 1600)]),
                Slide(
                    layout: .single,
                    cells: [photo(805, .lagoon, 1500, 2000)],
                    layers: [framedPhoto(806, .ember, centerY: 0.48, scale: 1.4, rotation: 0.04)]
                )
            ],
            createdAt: date(daysAgo: 28)
        )
    }

    /// A recipe, its steps numbered over the photos.
    private static var lemonTart: Project {
        let style = SlideStyle(spacing: 0.02, border: 0.04, background: butter)
        return Project(
            name: "Lemon Tart",
            aspectRatio: .square,
            slides: [
                Slide(
                    layout: .single,
                    cells: [photo(901, .ember, 1600, 1600, crop: ImageCrop(scale: 1.3, centerX: 0.6, centerY: 0.6))],
                    layers: [text("Lemon Tart", font: .handwriting, centerY: 0.2, scale: 1.3)],
                    style: style
                ),
                Slide(
                    layout: .twoColumns,
                    cells: [photo(902, .sunset, 1200, 1600), photo(903, .ember, 1200, 1600)],
                    layers: [step("1", centerX: 0.14), step("2", centerX: 0.64)],
                    style: style
                ),
                Slide(
                    layout: .twoColumns,
                    cells: [photo(904, .dusk, 1200, 1600), photo(905, .lagoon, 1200, 1600)],
                    layers: [step("3", centerX: 0.14), step("4", centerX: 0.64)],
                    style: style
                )
            ],
            createdAt: date(daysAgo: 35)
        )
    }

    private static let cream = RGBColor(red: 0.98, green: 0.95, blue: 0.89)
    private static let butter = RGBColor(red: 1, green: 0.95, blue: 0.8)
    private static let blush = RGBColor(red: 0.98, green: 0.91, blue: 0.9)
    private static let charcoal = RGBColor(red: 0.1, green: 0.1, blue: 0.11)
    private static let yellow = RGBColor(red: 1, green: 0.84, blue: 0.2)
    private static let orange = RGBColor(red: 1, green: 0.55, blue: 0.2)
    private static let pink = RGBColor(red: 0.98, green: 0.5, blue: 0.68)
    private static let violet = RGBColor(red: 0.47, green: 0.34, blue: 0.91)

    /// `SampleImages`' palettes in its order, which an image's ID picks with its last byte.
    private enum Palette: UInt8 {
        /// Orange over violet.
        case sunset
        /// Cyan over navy.
        case sky
        /// Yellow over red.
        case ember
        /// Mint over teal.
        case lagoon
        /// Pink over indigo.
        case dusk
    }

    /// White unless highlighted, with a shadow to lift it off the photo, which a highlight's box
    /// does without one.
    private static func text(
        _ text: String,
        font: LayerFont,
        color: RGBColor = .white,
        isHighlighted: Bool = false,
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        scale: Double = 1,
        rotation: Double = 0
    ) -> Layer {
        Layer(
            content: .text(TextLayer(text: text, font: font, color: color, hasShadow: !isHighlighted, isHighlighted: isHighlighted)),
            placement: LayerPlacement(centerX: centerX, centerY: centerY, scale: scale, rotation: rotation)
        )
    }

    /// A recipe step's number in a column's upper leading corner.
    private static func step(_ number: String, centerX: Double) -> Layer {
        text(number, font: .rounded, color: .white, isHighlighted: true, centerX: centerX, centerY: 0.14, scale: 0.8)
    }

    /// A star cut out of its background, outlined as a die-cut sticker is.
    private static func sticker(_ number: UInt16, _ palette: Palette, centerX: Double, centerY: Double, scale: Double) -> Layer {
        Layer(
            content: .image(ImageLayer(image: image(number, palette, 600, 600, format: .png), borderWidth: 0.05)),
            placement: LayerPlacement(centerX: centerX, centerY: centerY, scale: scale)
        )
    }

    /// A print with a white mat, lifted off the slide by a shadow.
    private static func framedPhoto(_ number: UInt16, _ palette: Palette, centerY: Double, scale: Double, rotation: Double) -> Layer {
        Layer(
            content: .image(ImageLayer(image: image(number, palette, 1600, 1200), borderWidth: 0.04, hasShadow: true)),
            placement: LayerPlacement(centerY: centerY, scale: scale, rotation: rotation)
        )
    }

    /// Photos are about 1,600 pixels on their longer side, sharp in a 13-inch iPad's strip, yet
    /// few enough that `SampleStore` draws the whole set in under a second at launch.
    /// `fromTray`, when given, is the tray photo the cell's photo was cloned from.
    private static func photo(
        _ number: UInt16,
        _ palette: Palette,
        _ width: Int,
        _ height: Int,
        crop: ImageCrop = ImageCrop(),
        fromTray trayNumber: UInt16? = nil
    ) -> Cell {
        var placed = image(number, palette, width, height)
        placed.crop = crop
        placed.trayPhotoID = trayNumber.map { trayPhotoID($0) }
        return Cell(image: placed)
    }

    /// Tray photo `number`, in the palette and shape of the cell's photo cloned from it, so the two
    /// match, and its copy, image `number` of the tray's own, which no cell's copy shares.
    private static func trayPhoto(_ number: UInt16, _ palette: Palette, _ width: Int, _ height: Int) -> TrayPhoto {
        TrayPhoto(id: trayPhotoID(number), image: image(number, palette, width, height, isTrays: true))
    }

    private static func trayPhotoID(_ number: UInt16) -> UUID {
        UUID(uuid: (0xDE, 0x30, 0xDE, 0x30, 0, 0, 0x40, 0, 0x80, 0, 0, 0x01, UInt8(number >> 8), UInt8(number & 0xFF), 0, 0))
    }

    /// `isTrays` sets an ID byte of its own, since tray numbers overlap other projects' images'.
    private static func image(
        _ number: UInt16,
        _ palette: Palette,
        _ width: Int,
        _ height: Int,
        format: ImageFileFormat = .jpeg,
        isTrays: Bool = false
    ) -> PlacedImage {
        let (high, low) = (UInt8(number >> 8), UInt8(number & 0xFF))
        let id = UUID(uuid: (0xDE, 0x30, 0xDE, 0x30, 0, 0, 0x40, 0, 0x80, 0, 0, 0, high, low, isTrays ? 1 : 0, palette.rawValue))
        return PlacedImage(id: id, assetIdentifier: nil, pixelWidth: width, pixelHeight: height, fileFormat: format)
    }

    private static func date(daysAgo: Double) -> Date {
        Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 - daysAgo * 86_400).rounded())
    }
}
#endif
