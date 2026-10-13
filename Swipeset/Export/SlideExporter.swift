//
//  SlideExporter.swift
//  Swipeset
//

import ImageIO
import UIKit

/// A slide written out for saving or sharing, with a small copy to preview it by.
nonisolated struct ExportedSlide: Identifiable, Sendable {
    let file: URL
    let thumbnail: CGImage?

    var id: URL { file }
}

/// A project's slides written out, and what they're missing.
nonisolated struct ExportResult: Sendable {
    let slides: [ExportedSlide]
    /// Cells with no photo, which export as the background.
    let emptyCells: Int
    /// Photos whose copies couldn't be read, which export as the background too.
    let missingPhotos: Int

    var files: [URL] {
        slides.map(\.file)
    }
}

/// Writes a project's slides out as images.
nonisolated protocol SlideExporting: Sendable {
    func export(_ project: Project) async throws -> ExportResult
}

/// Renders each slide at its shape's export size into a JPEG, a panorama into one for every slide
/// it spans, in a folder of its own under `ProjectPaths.exports`, named in order after the project.
nonisolated struct SlideExporter: SlideExporting {
    enum ExportError: Error {
        case unencodable
    }

    let paths: ProjectPaths
    /// Decodes a photo of a project at no more than a size, or nil when its copy is missing.
    let decode: @Sendable (PlacedImage, UUID, CGSize) -> CGImage?

    /// An exporter that reads photos from `paths`' copies.
    init(paths: ProjectPaths) {
        self.init(paths: paths) { image, projectID, size in
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(max(size.width, size.height).rounded(.up))
            ]
            let url = paths.imageFile(named: image.fileName, in: projectID)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else {
                return nil
            }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
    }

    init(paths: ProjectPaths, decode: @escaping @Sendable (PlacedImage, UUID, CGSize) -> CGImage?) {
        self.paths = paths
        self.decode = decode
    }

    @concurrent
    func export(_ project: Project) async throws -> ExportResult {
        // Earlier exports go now rather than when their sheet closed, since a share can still be
        // reading them after the sheet is gone.
        try? FileManager.default.removeItem(at: paths.exports)
        let folder = paths.exports.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = Self.fileName(for: project.name)
        let digits = max(2, String(project.carouselSlideCount).count)
        var slides: [ExportedSlide] = []
        var missingPhotos = 0
        for slide in project.slides {
            try Task.checkCancellation()
            // One slide's decodes at a time, rather than all of them at once.
            try autoreleasepool {
                missingPhotos += try SlideRenderer.render(slide, style: project.style, size: project.aspectRatio.exportSize) { image, size in
                    decode(image, project.id, size)
                } piece: { image in
                    try Task.checkCancellation()
                    guard let data = image.jpegData(compressionQuality: 0.92) else {
                        throw ExportError.unencodable
                    }
                    // Numbered through the carousel, a panorama's pieces among the other slides.
                    let number = String(slides.count + 1).leftPadded(to: digits)
                    let file = folder.appending(path: "\(name) \(number).jpg", directoryHint: .notDirectory)
                    try data.write(to: file)
                    slides.append(ExportedSlide(file: file, thumbnail: Self.thumbnail(of: file)))
                }
            }
        }
        let emptyCells = project.slides.reduce(0) { count, slide in
            count + slide.cells.count { $0.image == nil }
        }
        return ExportResult(slides: slides, emptyCells: emptyCells, missingPhotos: missingPhotos)
    }

    /// The project's name, safe as a file name, so shared files read as the project's.
    static func fileName(for name: String) -> String {
        let safe = name
            .components(separatedBy: CharacterSet(charactersIn: "/:\\"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return safe.isEmpty ? "Swipeset" : safe
    }

    /// Large enough for the preview strip on a 3x screen.
    private static func thumbnail(of file: URL) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 480
        ]
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

nonisolated private extension String {
    func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}
