//
//  EdgeScroll.swift
//  Carouline
//

import QuartzCore
import SwiftUI

/// How a finger held at a scroll view's edge scrolls it: the strip along a panorama, which runs past
/// the screen's sides, for a layer dragged there, so the layer can go anywhere along it, or the tray
/// along its photos, for one held there.
nonisolated enum EdgeScroll {
    /// A fingertip in from either edge, as far in as a finger can rest and still be on the screen.
    static let zone = LayerGeometry.minimumTarget
    /// At the very edge, about a phone's slide every half second, slow enough to stop where the
    /// layer's wanted.
    static let maximumSpeed: CGFloat = 700

    /// How fast to scroll, in points a second, for a finger at `x` on a strip `width` wide: toward
    /// whichever edge it's within `zone` of, faster the nearer, and negative toward the leading one.
    static func velocity(at x: CGFloat, across width: CGFloat) -> CGFloat {
        guard width > 2 * zone else {
            return 0
        }
        if x < zone {
            return -maximumSpeed * min(1, (zone - x) / zone)
        }
        if x > width - zone {
            return maximumSpeed * min(1, (x - (width - zone)) / zone)
        }
        return 0
    }
}

/// Calls back each frame the screen draws, with the seconds since the last, while it runs. A
/// display link rather than a timer, so a scroll it drives keeps in step with the screen.
final class FrameTicker: NSObject {
    private var link: CADisplayLink?
    private var tick: (TimeInterval) -> Void = { _ in }

    var isRunning: Bool {
        link != nil
    }

    func start(_ tick: @escaping (TimeInterval) -> Void) {
        stop()
        self.tick = tick
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Stops it, which the display link, holding on to it until then, needs.
    func stop() {
        link?.invalidate()
        link = nil
        tick = { _ in }
    }

    @objc private func step(_ link: CADisplayLink) {
        tick(link.targetTimestamp - link.timestamp)
    }
}
