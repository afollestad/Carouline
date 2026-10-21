//
//  LayerImageEffects.swift
//  Carouline
//

import CoreImage
import UIKit

/// The outline a transparent picture's border traces, rendered by Core Image for the screen and
/// the export alike, so the two match, with the picture drawn over it, or traced as loops for a
/// styled border to cut its edge along; and the export's blur, which blurs as SwiftUI's does on
/// screen.
nonisolated enum LayerImageEffects {
    /// How far past its edges a transparent picture's blur reaches, in sigmas, beyond which the
    /// Gaussian adds less than a level of an 8-bit color.
    static let blurReach: CGFloat = 3

    /// The longest side the screen renders an outline from, sharp enough for a layer filling a
    /// phone's slide, while a render stays quick enough to follow the border's slider.
    static let screenSide = 1024

    /// Where the blurred shape is cut: far below half, so the cut lands outside the shape, and low
    /// enough that a stroke a fortieth of the border's width still reaches it, so thin lettering
    /// gets its outline too. A straight edge blurred by a Gaussian of sigma σ falls to it
    /// `outlineReach` σ out, which sets the sigma for an outline's width. A blur grows a shape
    /// alike at any width, where a morphology filter tops out short of the 170 pixels a large
    /// layer's border can be.
    private static let cutLevel = 0.02
    /// The standard normal quantile of 1 - `cutLevel`.
    private static let outlineReach = 2.0537
    /// The standard normal density at `outlineReach`: how far a blurred straight edge falls per
    /// sigma at the cut, which spreads the cut over about a pixel to smooth it.
    private static let edgeSlope = 0.0484

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    /// One context for every render, which is costly to make. It works in sRGB, so the border's
    /// color goes in as it's stored, and the shape's levels are numbers no conversion touches.
    private static let context = CIContext(options: [.workingColorSpace: sRGB, .outputColorSpace: sRGB])
    /// Recent screen renders, so a layer drawn anew, as when it's selected or its editor opens,
    /// shows its outline at once. About a dozen of the largest, and it empties under memory
    /// pressure. `NSCache` is safe to use from any thread.
    private nonisolated(unsafe) static let screenRenders: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// The side a transparent picture's styled outline is traced from, both on screen and in the
    /// export, so the two cut the same teeth. Traced to within a quarter of a pixel here, it's
    /// within a pixel on a sticker two slides wide in an export.
    static let contourSide = 512

    /// How wide a band of a styled outline its cut never reaches, as a share of the border: around
    /// a thin stroke, whose outline reaches less than the border's width, a cut would otherwise
    /// eat it away.
    static let coreShare: CGFloat = 0.4

    /// The outline of `image`'s opaque shape grown by `width` pixels all round, filled with
    /// `color`, on a canvas `width` larger than `image` on each side, or nil when there's no width.
    /// The shape is the image's alpha cut at half, so a faint soft edge or drop shadow doesn't
    /// swell the outline into a blob.
    static func outline(of image: CGImage, width: CGFloat, color: RGBColor) -> CGImage? {
        guard width > 0 else {
            return nil
        }
        let input = CIImage(cgImage: image)
        let canvas = input.extent.insetBy(dx: -width, dy: -width)
        let none = CIVector(x: 0, y: 0, z: 0, w: 0)
        let alpha = CIVector(x: 0, y: 0, z: 0, w: 1)
        let sigma = width / outlineReach
        // How far the blurred edge falls across a pixel at the cut.
        let spread = edgeSlope / sigma
        let low = cutLevel - spread / 2
        let level = blurredShape(of: input, width: width, canvas: canvas)
            // The cut, ramped over about a pixel, in red.
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1 / spread, y: 0, z: 0, w: 0),
                "inputGVector": none,
                "inputBVector": none,
                "inputAVector": alpha,
                "inputBiasVector": CIVector(x: -low / spread, y: 0, z: 0, w: 0)
            ])
            .applyingFilter("CIColorClamp")
        // The border's color, as opaque as the ramp says.
        let outline = level.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": none,
            "inputGVector": none,
            "inputBVector": none,
            "inputAVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: color.red, y: color.green, z: color.blue, w: 0)
        ])
        return context.createCGImage(outline, from: canvas, format: .RGBA8, colorSpace: sRGB)
    }

    /// `input`'s shape, its alpha cut at half, blurred by the Gaussian whose `cutLevel` reaches
    /// `width` past its edge, in red on black over `canvas`.
    private static func blurredShape(of input: CIImage, width: CGFloat, canvas: CGRect) -> CIImage {
        let none = CIVector(x: 0, y: 0, z: 0, w: 0)
        let alpha = CIVector(x: 0, y: 0, z: 0, w: 1)
        return input
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": alpha,
                "inputGVector": alpha,
                "inputBVector": alpha,
                "inputAVector": none,
                "inputBiasVector": alpha
            ])
            .applyingFilter("CIColorThreshold", parameters: ["inputThreshold": 0.5])
            .composited(over: CIImage(color: .black).cropped(to: canvas))
            // Black past the canvas too, so the blur draws nothing in from beyond it.
            .clampedToExtent()
            .applyingGaussianBlur(sigma: width / outlineReach)
            .cropped(to: canvas)
    }

    /// The outline `outline(of:width:color:)` fills, `width` pixels round `image`'s shape, traced
    /// as loops, and its core, `coreShare` as wide, or nil when there's no width.
    static func contour(of image: CGImage, width: CGFloat) -> StickerContour? {
        guard width > 0 else {
            return nil
        }
        let input = CIImage(cgImage: image)
        let canvas = input.extent.insetBy(dx: -width, dy: -width)
        guard let outline = trace(blurredShape(of: input, width: width, canvas: canvas), canvas: canvas),
              let core = trace(blurredShape(of: input, width: coreShare * width, canvas: canvas), canvas: canvas) else {
            return nil
        }
        return StickerContour(outline: outline, core: core, borderWidth: Double(width) / Double(max(image.width, image.height, 1)))
    }

    /// Where `field`'s red crosses `cutLevel` over `canvas`, as loops in shares of the canvas from
    /// its top left, so they fit a frame of any size.
    private static func trace(_ field: CIImage, canvas: CGRect) -> [[CGPoint]]? {
        let bounds = canvas.integral
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        guard width > 0, height > 0 else {
            return nil
        }
        var values = [Float](repeating: 0, count: width * height)
        let isRendered = values.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else {
                return false
            }
            // Levels as numbers, which no color conversion touches, with the top row first.
            context.render(field, toBitmap: base, rowBytes: width * MemoryLayout<Float>.size, bounds: bounds, format: .Rf, colorSpace: nil)
            return true
        }
        guard isRendered else {
            return nil
        }
        let loops = ContourTracer.loops(in: values, width: width, height: height, level: Float(cutLevel), tolerance: 0.25)
        return loops.map { loop in
            loop.map { point in
                // The bitmap runs down from the top of `bounds`, and Core Image up from its bottom.
                CGPoint(
                    x: (bounds.minX + point.x - canvas.minX) / canvas.width,
                    y: (canvas.maxY - bounds.maxY + point.y) / canvas.height
                )
            }
        }
    }

    /// `image` blurred by a Gaussian of `sigma` pixels as an opaque photo is: its edges carried
    /// on past it for the blur, then cut back, so it stays sharp at its frame's edges, as
    /// SwiftUI's opaque blur keeps it.
    static func blurredInPlace(_ image: CGImage, sigma: CGFloat) -> CIImage {
        let input = CIImage(cgImage: image)
        return input.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: input.extent)
    }

    /// `image` blurred by a Gaussian of `sigma` pixels as a transparent picture is, spreading
    /// past its edges by `blurReach` sigmas, which the result's canvas grows by on each side.
    static func blurredOut(_ image: CGImage, sigma: CGFloat) -> CGImage? {
        let input = CIImage(cgImage: image)
        let canvas = input.extent.insetBy(dx: -blurReach * sigma, dy: -blurReach * sigma).integral
        return render(input.applyingGaussianBlur(sigma: sigma), from: canvas)
    }

    /// `image`'s pixels in `rect`, measured up from its bottom, as Core Image measures, in 8-bit
    /// sRGB.
    static func render(_ image: CIImage, from rect: CGRect) -> CGImage? {
        context.createCGImage(image, from: rect, format: .RGBA8, colorSpace: sRGB)
    }

    /// `image`'s outline for `picture`'s border, which is a share of the picture's longer side.
    static func outline(of image: CGImage, for picture: ImageLayer) -> CGImage? {
        outline(of: image, width: picture.borderWidth * CGFloat(max(image.width, image.height)), color: picture.borderColor)
    }

    /// The screen's last render of `picture`'s outline from its picture at `pixels`, if it's kept.
    static func cachedScreenOutline(for picture: ImageLayer, pixels: Int) -> CGImage? {
        screenRenders.object(forKey: screenKey(for: picture, pixels: pixels))
    }

    /// `picture`'s outline from `image`, made off the main actor.
    @concurrent
    static func screenOutline(of image: CGImage, for picture: ImageLayer) async -> CGImage? {
        outline(of: image, for: picture)
    }

    /// Keeps `outline`, shown for `picture` from its picture decoded at `pixels`, for
    /// `cachedScreenOutline(for:pixels:)`. Only shown ones are kept, so a slider's passing widths
    /// don't crowd out other layers' outlines.
    static func keepScreenOutline(_ outline: CGImage, for picture: ImageLayer, pixels: Int) {
        screenRenders.setObject(outline, forKey: screenKey(for: picture, pixels: pixels), cost: outline.bytesPerRow * outline.height)
    }

    /// `image`'s styled outline for `picture`'s border, from the picture decoded at `contourSide`.
    static func contour(of image: CGImage, for picture: ImageLayer) -> StickerContour? {
        contour(of: image, width: picture.borderWidth * CGFloat(max(image.width, image.height)))
    }

    /// The screen's last trace of `picture`'s styled outline, if it's kept.
    static func cachedContour(for picture: ImageLayer) -> StickerContour? {
        contours.object(forKey: contourKey(for: picture))
    }

    /// `picture`'s styled outline from `image`, traced off the main actor.
    @concurrent
    static func screenContour(of image: CGImage, for picture: ImageLayer) async -> StickerContour? {
        contour(of: image, for: picture)
    }

    /// Keeps `contour`, traced for `picture`, for `cachedContour(for:)`. Traces hold no pixels, so
    /// plenty are kept, and moving or pinching a layer never traces again.
    static func keepContour(_ contour: StickerContour, for picture: ImageLayer) {
        contours.setObject(contour, forKey: contourKey(for: picture))
    }

    private static let contours: NSCache<NSString, StickerContour> = {
        let cache = NSCache<NSString, StickerContour>()
        cache.countLimit = 200
        return cache
    }()

    private static func contourKey(for picture: ImageLayer) -> NSString {
        "\(picture.image.id.uuidString)-\(picture.borderWidth)" as NSString
    }

    private static func screenKey(for picture: ImageLayer, pixels: Int) -> NSString {
        let color = picture.borderColor
        return "\(picture.image.id.uuidString)-\(pixels)-\(picture.borderWidth)-\(color.red)-\(color.green)-\(color.blue)" as NSString
    }
}

/// A transparent picture's outline traced as loops, in shares of its outline's canvas, the picture
/// grown by its border all round, from the top left: the outline, and its core, which a styled
/// edge's fill keeps whole. Immutable, so safe to share across threads.
nonisolated final class StickerContour: Sendable {
    let outline: [[CGPoint]]
    let core: [[CGPoint]]
    /// The border it was traced for, as a share of the picture's longer side.
    let borderWidth: Double

    init(outline: [[CGPoint]], core: [[CGPoint]], borderWidth: Double) {
        self.outline = outline
        self.core = core
        self.borderWidth = borderWidth
    }
}
