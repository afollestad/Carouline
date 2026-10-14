//
//  CropGeometry.swift
//  Carouline
//

import CoreGraphics

/// Where a photo draws in its cell under an `ImageCrop`, and how drags and pinches change it.
/// Every result covers the cell, so no background ever shows past a photo's edge.
nonisolated enum CropGeometry {
    /// The frame `imageSize` draws at inside a cell of `cellSize`, in the cell's coordinates.
    static func frame(imageSize: CGSize, cellSize: CGSize, crop: ImageCrop) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, cellSize.width > 0, cellSize.height > 0 else {
            return CGRect(origin: .zero, size: cellSize)
        }
        let fill = max(cellSize.width / imageSize.width, cellSize.height / imageSize.height)
        let scale = fill * clampedScale(crop.scale)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = cellSize.width / 2 - crop.centerX * size.width
        let y = cellSize.height / 2 - crop.centerY * size.height
        return CGRect(
            x: min(0, max(cellSize.width - size.width, x)),
            y: min(0, max(cellSize.height - size.height, y)),
            width: size.width,
            height: size.height
        )
    }

    /// `crop` moved so the photo follows a drag of `translation` in a cell of `cellSize`.
    static func panned(_ crop: ImageCrop, by translation: CGSize, imageSize: CGSize, cellSize: CGSize) -> ImageCrop {
        let start = frame(imageSize: imageSize, cellSize: cellSize, crop: crop)
        let moved = start.offsetBy(dx: translation.width, dy: translation.height)
        return self.crop(showing: moved, imageSize: imageSize, cellSize: cellSize)
    }

    /// `crop` zoomed by `magnification`, keeping the point of the photo under `anchor`, in the
    /// cell's coordinates, where it is, as a pinch does.
    static func zoomed(
        _ crop: ImageCrop,
        by magnification: CGFloat,
        about anchor: CGPoint,
        imageSize: CGSize,
        cellSize: CGSize
    ) -> ImageCrop {
        let start = frame(imageSize: imageSize, cellSize: cellSize, crop: crop)
        let oldScale = clampedScale(crop.scale)
        let newScale = clampedScale(oldScale * magnification)
        let factor = newScale / oldScale
        let zoomed = CGRect(
            x: anchor.x - (anchor.x - start.minX) * factor,
            y: anchor.y - (anchor.y - start.minY) * factor,
            width: start.width * factor,
            height: start.height * factor
        )
        return self.crop(showing: zoomed, imageSize: imageSize, cellSize: cellSize)
    }

    /// `crop` at a new zoom, about the cell's center, as a slider sets it.
    static func zoomed(_ crop: ImageCrop, to scale: Double, imageSize: CGSize, cellSize: CGSize) -> ImageCrop {
        let center = CGPoint(x: cellSize.width / 2, y: cellSize.height / 2)
        let magnification = clampedScale(scale) / clampedScale(crop.scale)
        return zoomed(crop, by: magnification, about: center, imageSize: imageSize, cellSize: cellSize)
    }

    /// The crop that draws the photo at `frame`, pulled back to cover the cell. Storing the
    /// covering center, rather than wherever a drag overshot to, keeps a later cell shape from
    /// revealing a part of the photo the user pushed out of view.
    static func crop(showing frame: CGRect, imageSize: CGSize, cellSize: CGSize) -> ImageCrop {
        guard imageSize.width > 0, imageSize.height > 0, cellSize.width > 0, cellSize.height > 0 else {
            return ImageCrop()
        }
        let fill = max(cellSize.width / imageSize.width, cellSize.height / imageSize.height)
        let scale = clampedScale(frame.width / (imageSize.width * fill))
        let size = CGSize(width: imageSize.width * fill * scale, height: imageSize.height * fill * scale)
        let x = min(0, max(cellSize.width - size.width, frame.minX))
        let y = min(0, max(cellSize.height - size.height, frame.minY))
        return ImageCrop(
            scale: scale,
            centerX: (cellSize.width / 2 - x) / size.width,
            centerY: (cellSize.height / 2 - y) / size.height
        )
    }

    static func clampedScale(_ scale: Double) -> Double {
        guard scale.isFinite else {
            return 1
        }
        return min(max(scale, 1), ImageCrop.maximumScale)
    }
}
